# --
# Kernel/System/ProcessManagement/TransitionAction/StampItWebhook.pm
#
# BESCHREIBUNG:
#   Transition Action für den Beschaffungsprozess.
#   Wird ausgelöst beim Übergang "Lieferung erhalten → Rechnung erhalten"
#   (Transition 'Transition-Rechnung-Erhalten').
#
#   Was dieses Modul tut:
#     1. Holt das neueste PDF-Attachment aus dem Ticket-Artikel
#        (die im Activity Dialog 'ActivityDialog-Rechnung-Erfassen'
#         hochgeladene Rechnung – Feld 'Article').
#     2. Baut aus den Beschaffungs-Dynamic-Fields die Kontierungs-Metadaten
#        (StampMetadata, siehe doc/stampit_api.yaml) als JSON.
#     3. Sendet Metadaten + PDF als multipart/form-data POST an die StampIt!-API.
#     4. Empfängt das gestempelte PDF zurück und hängt es als neues
#        Attachment an das Ticket.
#
# INSTALLATION (über die /overrides PVC, vgl. CLAUDE.md):
#   docker/overrides/Kernel/System/ProcessManagement/TransitionAction/StampItWebhook.pm
#   -> wird beim Boot nach /opt/znuny/Custom/ synchronisiert und via @INC geladen.
#
# KONFIGURATION:
#   Entweder im Transition-Action-Config (Vorrang, siehe import_process.pl) oder
#   über die System Configuration:
#     Process::TransitionAction::StampItWebhook::APIURL
#     Process::TransitionAction::StampItWebhook::APIKey          (optional, Bearer-Token)
#     Process::TransitionAction::StampItWebhook::TimeoutSeconds
# --

package Kernel::System::ProcessManagement::TransitionAction::StampItWebhook;

use strict;
use warnings;
use utf8;

use HTTP::Tiny;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

=head1 NAME

Kernel::System::ProcessManagement::TransitionAction::StampItWebhook

=head1 DESCRIPTION

Sendet das neueste PDF-Attachment eines Tickets zusammen mit den
Kontierungs-Metadaten an die StampIt!-API und hängt das zurückgelieferte
gestempelte PDF als neues Attachment an.

=head1 PUBLIC INTERFACE

=head2 new()

Erstellt eine neue Instanz. Wird von Znuny automatisch aufgerufen.

=cut

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless( $Self, $Type );
    return $Self;
}

=head2 Run()

Hauptmethode der Transition Action.

    my $Success = $TransitionActionObject->Run(
        UserID                   => 123,
        Ticket                   => \%Ticket,       # aktuelles Ticket-Hash (inkl. DynamicField_*)
        ProcessEntityID          => 'Process-...',
        ActivityEntityID         => 'Activity-...',
        TransitionEntityID       => 'Transition-Rechnung-Erhalten',
        TransitionActionEntityID => 'TA-StampIt-Rechnung',
        Config => {
            # Optionale Überschreibung der System-Konfiguration:
            APIURL         => 'http://stampit:5000/stampit',
            APIKey         => 'Bearer sk-...',
            TimeoutSeconds => 60,

            # Mapping StampMetadata-Feld => Dynamic-Field-Name (ohne 'DynamicField_').
            # Überschreibt die Standardzuordnung selektiv.
            MetadataMapping => {
                kapitel      => 'BeschaffungKapitel',
                betrag       => 'BeschaffungRechnungsBetragBrutto',
            },

            # Statische / Vorgabe-Werte für Felder ohne Dynamic Field.
            MetadataStatic => {
                inventarisierung => 'false',
                haushaltsjahr    => '2025',
            },
        },
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');

    # ----------------------------------------------------------------
    # Parameter-Validierung
    # ----------------------------------------------------------------
    for my $Needed (qw(UserID Ticket Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "StampItWebhook: Fehlender Parameter '$Needed'!",
            );
            return;
        }
    }

    my $TicketID = $Param{Ticket}->{TicketID};

    # ----------------------------------------------------------------
    # Konfiguration zusammenführen (System Config < Transition Config)
    # ----------------------------------------------------------------
    my $APIURL = $Param{Config}->{APIURL}
        || $ConfigObject->Get('Process::TransitionAction::StampItWebhook::APIURL')
        || '';

    my $APIKey = $Param{Config}->{APIKey}
        || $ConfigObject->Get('Process::TransitionAction::StampItWebhook::APIKey')
        || '';

    my $Timeout = $Param{Config}->{TimeoutSeconds}
        || $ConfigObject->Get('Process::TransitionAction::StampItWebhook::TimeoutSeconds')
        || 60;

    if ( !$APIURL ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: Keine APIURL konfiguriert (TicketID: $TicketID).",
        );
        return;
    }

    # ----------------------------------------------------------------
    # Schritt 1: Neuestes (nicht-gestempeltes) PDF-Attachment holen
    # ----------------------------------------------------------------
    my $PDFAttachment = $Self->_GetLatestPDFAttachment(
        TicketID      => $TicketID,
        ArticleObject => $ArticleObject,
        LogObject     => $LogObject,
    );

    if ( !$PDFAttachment ) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => "StampItWebhook: Kein PDF-Attachment in TicketID $TicketID gefunden. Überspringe.",
        );
        # Kein hartes Fehlschlagen – Transition trotzdem durchlassen
        return 1;
    }

    # ----------------------------------------------------------------
    # Schritt 2: Kontierungs-Metadaten aus Dynamic Fields aufbauen.
    # 'bemerkung' kommt aus dem Artikel-Text des Activity Dialogs (nicht aus
    # einem Dynamic Field), vgl. doc/map_znuny_stampit.md.
    # ----------------------------------------------------------------
    my $Bemerkung = $Self->_GetArticleText(
        TicketID      => $TicketID,
        ArticleID     => $PDFAttachment->{ArticleID},
        ArticleObject => $ArticleObject,
    );

    my $Metadata = $Self->_BuildMetadata(
        Ticket    => $Param{Ticket},
        Config    => $Param{Config},
        Bemerkung => $Bemerkung,
        LogObject => $LogObject,
    );

    $LogObject->Log(
        Priority => 'info',
        Message  => "StampItWebhook: PDF '$PDFAttachment->{Filename}' "
                  . "(" . length( $PDFAttachment->{Content} ) . " Bytes) "
                  . "wird an StampIt! ($APIURL) gesendet.",
    );

    # ----------------------------------------------------------------
    # Schritt 3: PDF + Metadaten per HTTP POST an die API senden
    # ----------------------------------------------------------------
    my $APIResponse = $Self->_PostToAPI(
        APIURL     => $APIURL,
        APIKey     => $APIKey,
        Timeout    => $Timeout,
        Attachment => $PDFAttachment,
        Metadata   => $Metadata,
        TicketID   => $TicketID,
        LogObject  => $LogObject,
    );

    if ( !$APIResponse ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: StampIt!-Aufruf fehlgeschlagen für TicketID $TicketID.",
        );
        # Entscheidung: Transition trotzdem erlauben, aber Fehler loggen.
        return 1;
    }

    # ----------------------------------------------------------------
    # Schritt 4: Gestempeltes PDF als Attachment anhängen
    # ----------------------------------------------------------------
    $Self->_AttachStampedPDF(
        TicketID         => $TicketID,
        APIResponse      => $APIResponse,
        OriginalFilename => $PDFAttachment->{Filename},
        ArticleObject    => $ArticleObject,
        LogObject        => $LogObject,
        UserID           => $Param{UserID},
    );

    return 1;
}

# ================================================================
# PRIVATE METHODS
# ================================================================

# ----------------------------------------------------------------
# _GetLatestPDFAttachment
# Durchsucht alle Artikel des Tickets nach dem neuesten PDF-Attachment.
# Bereits gestempelte Ausgaben dieses Moduls (Suffix '_gestempelt') werden
# übersprungen, um Endlos-/Doppel-Stempelung zu vermeiden.
# Gibt HashRef { Filename, ContentType, Content, ArticleID } zurück oder undef.
# ----------------------------------------------------------------
sub _GetLatestPDFAttachment {
    my ( $Self, %Param ) = @_;

    my $ArticleObject = $Param{ArticleObject};
    my $TicketID      = $Param{TicketID};

    my @Articles = $ArticleObject->ArticleList(
        TicketID  => $TicketID,
        OnlyFirst => 0,
    );

    ARTICLE:
    for my $ArticleRef ( reverse @Articles ) {
        my $ArticleID            = $ArticleRef->{ArticleID};
        my $ArticleBackendObject = $ArticleObject->BackendForArticle(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
        );

        my %AttachmentIndex = $ArticleBackendObject->ArticleAttachmentIndex(
            TicketID         => $TicketID,
            ArticleID        => $ArticleID,
            ExcludePlainText => 1,
            ExcludeHTMLBody  => 1,
        );

        ATTACHMENT:
        for my $AttachmentID ( sort { $b <=> $a } keys %AttachmentIndex ) {
            my $AttInfo = $AttachmentIndex{$AttachmentID};

            # Nur PDFs
            next ATTACHMENT unless (
                ( $AttInfo->{ContentType} && $AttInfo->{ContentType} =~ m{application/pdf}i )
                || ( $AttInfo->{Filename} && $AttInfo->{Filename} =~ m{\.pdf$}i )
            );

            # Eigene gestempelte Ausgaben ignorieren
            next ATTACHMENT if ( $AttInfo->{Filename} && $AttInfo->{Filename} =~ m{_gestempelt\.pdf$}i );

            my %Attachment = $ArticleBackendObject->ArticleAttachment(
                TicketID  => $TicketID,
                ArticleID => $ArticleID,
                FileID    => $AttachmentID,
            );

            if ( $Attachment{Content} ) {
                return {
                    Filename    => $Attachment{Filename}    || 'rechnung.pdf',
                    ContentType => $Attachment{ContentType} || 'application/pdf',
                    Content     => $Attachment{Content},
                    ArticleID   => $ArticleID,
                };
            }
        }
    }

    return;    # kein PDF gefunden
}

# ----------------------------------------------------------------
# _BuildMetadata
# Baut den StampMetadata-Hash (siehe doc/stampit_api.yaml) aus den
# Beschaffungs-Dynamic-Fields des Tickets auf.
# Liefert ein HashRef mit allen StampMetadata-Schlüsseln (Strings).
# ----------------------------------------------------------------
sub _BuildMetadata {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};
    my $Config = $Param{Config};

    # Vollständige Liste der Metadaten-Felder (alle als String).
    # 'zahlungspartner' ist im StampMetadata-Schema nicht zwingend, wird aber
    # gemäß doc/map_znuny_stampit.md mitgesendet (Backend ignoriert Unbekanntes).
    my @Keys = qw(
        kapitel titel festlegung projekt ausgabeart kostenstelle kostenart
        anwendung haushaltsjahr inventarisierung bemerkung betrag
        hauptgeraet nutzer raum klassifikation zahlungspartner
    );

    # Standardzuordnung: API-Feld => Dynamic-Field-Name (ohne 'DynamicField_'),
    # gemäß doc/map_znuny_stampit.md. 'bemerkung' wird NICHT aus einem DF,
    # sondern aus dem Artikel-Text befüllt (siehe unten).
    my %Mapping = (
        kapitel         => 'BeschaffungKapitel',
        titel           => 'BeschaffungTitel',
        festlegung      => 'BeschaffungFestlegung',
        projekt         => 'BeschaffungKostentraeger',
        ausgabeart      => 'BeschaffungAusgabenart',
        kostenstelle    => 'BeschaffungKostenstelle',
        kostenart       => 'BeschaffungKostenart',
        anwendung       => 'BeschaffungAnwendung',
        haushaltsjahr   => 'BeschaffungHaushaltsjahr',
        inventarisierung => 'BeschaffungInventarisierung',
        betrag          => 'BeschaffungRechnungsBetragBrutto',
        hauptgeraet     => 'BeschaffungHauptgeraet',
        nutzer          => 'BeschaffungNutzer',
        raum            => 'BeschaffungRaum',
        klassifikation  => 'BeschaffungKlassifikation',
        zahlungspartner => 'BeschaffungLieferant',
    );
    if ( ref $Config->{MetadataMapping} eq 'HASH' ) {
        %Mapping = ( %Mapping, %{ $Config->{MetadataMapping} } );
    }

    # Statische Vorgaben / Fallbacks für Felder, deren Dynamic Field leer ist
    my %Static = (
        inventarisierung => 'false',
        haushaltsjahr    => ( (localtime)[5] + 1900 ),
    );
    if ( ref $Config->{MetadataStatic} eq 'HASH' ) {
        %Static = ( %Static, %{ $Config->{MetadataStatic} } );
    }

    # Initialisieren: alle Schlüssel leer, dann statische Vorgaben überlagern
    my %Metadata = map { $_ => '' } @Keys;
    %Metadata = ( %Metadata, map { $_ => $Static{$_} } grep { exists $Static{$_} } @Keys );

    # Dynamic-Field-Werte überlagern (nur wenn nicht leer)
    KEY:
    for my $Key ( keys %Mapping ) {
        next KEY unless grep { $_ eq $Key } @Keys;
        my $DFName = $Mapping{$Key};
        my $Value  = $Self->_GetDFValue( Ticket => $Ticket, Name => $DFName );
        next KEY unless ( defined $Value && length $Value );
        $Metadata{$Key} = $Value;
    }

    # 'bemerkung' aus dem Artikel-Text (Activity Dialog), falls vorhanden
    if ( defined $Param{Bemerkung} && length $Param{Bemerkung} ) {
        $Metadata{bemerkung} = $Param{Bemerkung};
    }

    # StampMetadata erwartet ausschließlich String-Werte. Numerische Werte
    # (z.B. das Standard-Haushaltsjahr aus localtime) würden sonst als JSON-Zahl
    # kodiert ("haushaltsjahr":2026) und von der API mit
    # "Error parsing JSON data" abgelehnt. Daher alle Werte stringifizieren.
    for my $Key (@Keys) {
        $Metadata{$Key} = defined $Metadata{$Key} ? "$Metadata{$Key}" : '';
    }

    return \%Metadata;
}

# ----------------------------------------------------------------
# _GetArticleText
# Liefert den (gekürzten, von HTML befreiten) Text-Body eines Artikels –
# wird als 'bemerkung' an StampIt! übergeben.
# ----------------------------------------------------------------
sub _GetArticleText {
    my ( $Self, %Param ) = @_;

    my $ArticleObject = $Param{ArticleObject};
    my $TicketID      = $Param{TicketID};
    my $ArticleID     = $Param{ArticleID};
    return '' if !$ArticleID;

    my $ArticleBackendObject = $ArticleObject->BackendForArticle(
        TicketID  => $TicketID,
        ArticleID => $ArticleID,
    );
    return '' if !$ArticleBackendObject;

    my %Article = $ArticleBackendObject->ArticleGet(
        TicketID      => $TicketID,
        ArticleID     => $ArticleID,
        DynamicFields => 0,
        UserID        => 1,
    );

    my $Body = $Article{Body} // '';

    # HTML-Body grob in Text wandeln
    if ( ( $Article{ContentType} // '' ) =~ m{text/html}i || $Body =~ m{<\w+} ) {
        $Body =~ s{<br\s*/?>}{\n}gi;
        $Body =~ s{<[^>]+>}{}g;
    }
    $Body =~ s{^\s+|\s+$}{}g;

    # auf eine sinnvolle Länge begrenzen
    if ( length $Body > 500 ) {
        $Body = substr( $Body, 0, 500 );
    }

    return $Body;
}

# ----------------------------------------------------------------
# _GetDFValue
# Liest einen Dynamic-Field-Wert: bevorzugt aus dem übergebenen Ticket-Hash
# (DynamicField_<Name>), sonst per Backend-ValueGet nachladen.
# Gibt immer einen String zurück (oder undef wenn nicht vorhanden).
# ----------------------------------------------------------------
sub _GetDFValue {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};
    my $Name   = $Param{Name};
    return if !$Name;

    # 1) direkt aus dem Ticket-Hash
    my $Value = $Ticket->{ "DynamicField_$Name" };
    if ( defined $Value ) {
        return ref $Value eq 'ARRAY' ? join( ', ', grep { defined } @{$Value} ) : $Value;
    }

    # 2) Fallback: aus der DB nachladen
    my $TicketID = $Ticket->{TicketID};
    return if !$TicketID;

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DFBackendObject    = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $DFConfig = $DynamicFieldObject->DynamicFieldGet( Name => $Name );
    return if !$DFConfig;

    my $Stored = $DFBackendObject->ValueGet(
        DynamicFieldConfig => $DFConfig,
        ObjectID           => $TicketID,
    );
    return if !defined $Stored;
    return ref $Stored eq 'ARRAY' ? join( ', ', grep { defined } @{$Stored} ) : $Stored;
}

# ----------------------------------------------------------------
# _PostToAPI
# Sendet Metadaten (JSON) + PDF als multipart/form-data POST an StampIt!.
# Erwartet im Erfolgsfall ein PDF zurück.
# Gibt HashRef { RawBody, ContentType, Status } zurück oder undef.
# ----------------------------------------------------------------
sub _PostToAPI {
    my ( $Self, %Param ) = @_;

    my $APIURL     = $Param{APIURL};
    my $APIKey     = $Param{APIKey};
    my $Timeout    = $Param{Timeout};
    my $Attachment = $Param{Attachment};
    my $Metadata   = $Param{Metadata};
    my $LogObject  = $Param{LogObject};

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # Metadaten als JSON-String (UTF-8 Bytes) kodieren
    my $MetadataJSON = $JSONObject->Encode( Data => $Metadata );
    if ( !defined $MetadataJSON ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: Konnte Metadaten nicht als JSON kodieren.",
        );
        return;
    }
    utf8::encode($MetadataJSON) if utf8::is_utf8($MetadataJSON);

    # ----------------------------------------------------------
    # Multipart-Body manuell aufbauen (HTTP::Tiny kann kein multipart nativ).
    # Genau zwei Parts wie in doc/stampit_api.yaml gefordert:
    #   'metadata' (application/json) und 'file' (application/pdf)
    # ----------------------------------------------------------
    my $Boundary = 'ZnunyStampItBoundary' . time() . $$;

    my $Filename = $Attachment->{Filename};
    $Filename =~ s{["\r\n]}{}g;    # Header-Injection vermeiden

    my $Body = '';

    $Body .= "--$Boundary\r\n";
    $Body .= "Content-Disposition: form-data; name=\"metadata\"\r\n";
    $Body .= "Content-Type: application/json\r\n\r\n";
    $Body .= $MetadataJSON;
    $Body .= "\r\n";

    $Body .= "--$Boundary\r\n";
    $Body .= "Content-Disposition: form-data; name=\"file\"; filename=\"$Filename\"\r\n";
    $Body .= "Content-Type: application/pdf\r\n";
    $Body .= "Content-Transfer-Encoding: binary\r\n\r\n";
    $Body .= $Attachment->{Content};
    $Body .= "\r\n";

    $Body .= "--$Boundary--\r\n";

    my %Headers = (
        'Content-Type'   => "multipart/form-data; boundary=$Boundary",
        'Content-Length' => length($Body),
        'Accept'         => 'application/pdf, application/json, */*',
        'User-Agent'     => 'Znuny-StampItWebhook/1.0',
    );

    if ($APIKey) {
        $Headers{'Authorization'} = ( $APIKey =~ m{^Bearer\s}i ) ? $APIKey : "Bearer $APIKey";
    }

    my $HTTP = HTTP::Tiny->new( timeout => $Timeout );

    my $Response = $HTTP->request(
        'POST',
        $APIURL,
        {
            headers => \%Headers,
            content => $Body,
        }
    );

    my $ResponseContentType = $Response->{headers}{'content-type'} || '';

    if ( !$Response->{success} ) {

        # Versuch, die JSON-Fehlermeldung der API auszuwerten
        my $Detail = $Response->{content} || '(kein Body)';
        if ( $ResponseContentType =~ m{application/json}i && $Response->{content} ) {
            my $Parsed = $JSONObject->Decode( Data => $Response->{content} );
            if ( ref $Parsed eq 'HASH' && $Parsed->{error} ) {
                $Detail = $Parsed->{error};
                $Detail .= " ($Parsed->{details})" if $Parsed->{details};
            }
        }
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: HTTP-Fehler $Response->{status} beim POST an $APIURL: $Detail",
        );
        return;
    }

    # Erfolgsfall: es muss ein PDF zurückkommen
    if ( $ResponseContentType !~ m{application/pdf}i ) {
        $LogObject->Log(
            Priority => 'warning',
            Message  => "StampItWebhook: Unerwarteter Content-Type '$ResponseContentType' "
                      . "in der StampIt!-Antwort (erwartet application/pdf).",
        );
    }

    $LogObject->Log(
        Priority => 'info',
        Message  => "StampItWebhook: StampIt! antwortete mit Status $Response->{status}, "
                  . length( $Response->{content} || '' ) . " Bytes ($ResponseContentType).",
    );

    return {
        RawBody     => $Response->{content},
        ContentType => $ResponseContentType,
        Status      => $Response->{status},
    };
}

# ----------------------------------------------------------------
# _AttachStampedPDF
# Hängt das gestempelte PDF an einen neuen internen Artikel des Tickets.
# ----------------------------------------------------------------
sub _AttachStampedPDF {
    my ( $Self, %Param ) = @_;

    my $TicketID         = $Param{TicketID};
    my $APIResponse      = $Param{APIResponse};
    my $OriginalFilename = $Param{OriginalFilename} || 'rechnung.pdf';
    my $ArticleObject    = $Param{ArticleObject};
    my $LogObject        = $Param{LogObject};
    my $UserID           = $Param{UserID};

    if ( !$APIResponse->{RawBody} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: Leere StampIt!-Antwort – nichts anzuhängen (TicketID: $TicketID).",
        );
        return;
    }

    my $BaseName = $OriginalFilename;
    $BaseName =~ s{\.pdf$}{}i;
    my $AttachFilename = "${BaseName}_gestempelt.pdf";

    my $ArticleBackendObject = $ArticleObject->BackendForChannel(
        ChannelName => 'Internal',
    );

    my $NewArticleID = $ArticleBackendObject->ArticleCreate(
        TicketID             => $TicketID,
        SenderType           => 'system',
        # Muss für den Kunden sichtbar sein: der Besteller muss die gestempelte
        # Rechnung im Kundenportal sehen und herunterladen können, um sie zu
        # kontieren / freizugeben (vgl. ActivityDialog-Rechnung-Kontieren).
        IsVisibleForCustomer => 1,
        From                 => 'Znuny Beschaffungsprozess <znuny@localhost>',
        Subject              => "Gestempelte Rechnung (StampIt!): $AttachFilename",
        Body                 => "Die Rechnung wurde von der StampIt!-API mit dem "
                              . "Kontierungsstempel versehen. Das gestempelte PDF "
                              . "ist als Attachment beigefügt.",
        ContentType          => 'text/plain; charset=utf-8',
        HistoryType          => 'AddNote',
        HistoryComment       => 'Rechnung durch StampItWebhook gestempelt',
        UserID               => $UserID,
        NoAgentNotify        => 1,
    );

    if ( !$NewArticleID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: Konnte keinen Artikel für das gestempelte PDF erstellen (TicketID: $TicketID).",
        );
        return;
    }

    my $AttachSuccess = $ArticleBackendObject->ArticleWriteAttachment(
        TicketID    => $TicketID,
        ArticleID   => $NewArticleID,
        Filename    => $AttachFilename,
        ContentType => 'application/pdf',
        Content     => $APIResponse->{RawBody},
        UserID      => $UserID,
    );

    if ($AttachSuccess) {
        $LogObject->Log(
            Priority => 'info',
            Message  => "StampItWebhook: Gestempeltes PDF '$AttachFilename' "
                      . "erfolgreich angehängt (ArticleID: $NewArticleID).",
        );
    }
    else {
        $LogObject->Log(
            Priority => 'error',
            Message  => "StampItWebhook: Fehler beim Schreiben des gestempelten PDFs.",
        );
    }

    return $AttachSuccess;
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY.
You can redistribute it and/or modify it under the terms of the
GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

=cut
