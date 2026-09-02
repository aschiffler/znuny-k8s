#!/usr/bin/perl
# --
# scripts/test/ProcessManagement/TransitionAction/StampItWebhook.t
#
# Testet das StampItWebhook Transition Action Modul.
# Ausführen (im Pod):
#   cd /opt/znuny
#   bin/znuny.Console.pl Dev::UnitTest::Run \
#       --test ProcessManagement/TransitionAction/StampItWebhook
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# ================================================================
# Test 1: Modul lässt sich laden
# ================================================================
my $WebhookModule = $Kernel::OM->Get(
    'Kernel::System::ProcessManagement::TransitionAction::StampItWebhook'
);

$Self->True(
    $WebhookModule,
    'StampItWebhook Modul geladen',
);

# ================================================================
# Test 2: Run() ohne APIURL → kein Absturz, gibt undef zurück
# ================================================================
{
    my %TestTicket = (
        TicketID     => 99999,
        TicketNumber => 'TEST-99999',
    );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $ConfigObject->Set(
        Key   => 'Process::TransitionAction::StampItWebhook::APIURL',
        Value => '',    # leer → soll graceful abbrechen
    );

    my $Result = $WebhookModule->Run(
        UserID                   => 1,
        Ticket                   => \%TestTicket,
        Config                   => {},
        ProcessEntityID          => 'Process-Beschaffung-001',
        ActivityEntityID         => 'Activity-Lieferung-Erhalten',
        TransitionEntityID       => 'Transition-Rechnung-Erhalten',
        TransitionActionEntityID => 'TA-StampIt-Rechnung',
    );

    $Self->False(
        $Result,
        'Run() ohne APIURL gibt undef zurück (kein Absturz)',
    );
}

# ================================================================
# Test 3: Erwartete Methoden vorhanden
# ================================================================
for my $Method (qw(_GetLatestPDFAttachment _BuildMetadata _GetDFValue _GetArticleText _PostToAPI _AttachStampedPDF)) {
    $Self->True(
        $WebhookModule->can($Method),
        "$Method Methode vorhanden",
    );
}

# ================================================================
# Test 4: _BuildMetadata liefert alle StampMetadata-Schlüssel und
#         zieht Werte aus den Dynamic Fields des Tickets
# ================================================================
{
    my %TestTicket = (
        TicketID                              => 99999,
        DynamicField_BeschaffungKapitel       => '05250',
        DynamicField_BeschaffungTitel         => '68530',
        DynamicField_BeschaffungFestlegung    => '1234567',
        DynamicField_BeschaffungKostenstelle  => '12345',
        DynamicField_BeschaffungKostenart     => '421000',
        DynamicField_BeschaffungAusgabenart   => 'A1',
        DynamicField_BeschaffungKostentraeger => 'FBxxx',
        DynamicField_BeschaffungAnwendung     => '01',
        DynamicField_BeschaffungHaushaltsjahr => '2025',
        DynamicField_BeschaffungInventarisierung     => 'true',
        DynamicField_BeschaffungRechnungsBetragBrutto => '1234,56',
        DynamicField_BeschaffungLieferant     => 'Testlieferant GmbH',
        DynamicField_BeschaffungNutzer        => 'Max Mustermann',
        DynamicField_BeschaffungRaum          => 'A.1.01',
        DynamicField_BeschaffungKlassifikation => 'EDV',
        DynamicField_BeschaffungHauptgeraet   => 'PC-001',
    );

    my $Metadata = $WebhookModule->_BuildMetadata(
        Ticket    => \%TestTicket,
        Config    => {},
        Bemerkung => 'Rechnung XY vom 01.01.2025',
        LogObject => $Kernel::OM->Get('Kernel::System::Log'),
    );

    $Self->Is( ref $Metadata, 'HASH', '_BuildMetadata liefert HashRef' );

    my @Keys = qw(
        kapitel titel festlegung projekt ausgabeart kostenstelle kostenart
        anwendung haushaltsjahr inventarisierung bemerkung betrag
        hauptgeraet nutzer raum klassifikation zahlungspartner
    );
    my $AllPresent = 1;
    for my $K (@Keys) {
        $AllPresent = 0 if !exists $Metadata->{$K};
    }
    $Self->True( $AllPresent, '_BuildMetadata enthält alle Metadaten-Schlüssel (inkl. zahlungspartner)' );

    $Self->Is( $Metadata->{kapitel},        '05250',   'kapitel aus DF BeschaffungKapitel' );
    $Self->Is( $Metadata->{titel},          '68530',   'titel aus DF BeschaffungTitel' );
    $Self->Is( $Metadata->{festlegung},     '1234567', 'festlegung aus DF BeschaffungFestlegung' );
    $Self->Is( $Metadata->{kostenstelle},   '12345',   'kostenstelle aus DF BeschaffungKostenstelle' );
    $Self->Is( $Metadata->{kostenart},      '421000',  'kostenart aus DF BeschaffungKostenart' );
    $Self->Is( $Metadata->{projekt},        'FBxxx',   'projekt aus DF BeschaffungKostentraeger' );
    $Self->Is( $Metadata->{ausgabeart},     'A1',      'ausgabeart aus DF BeschaffungAusgabenart' );
    $Self->Is( $Metadata->{anwendung},      '01',      'anwendung aus DF BeschaffungAnwendung' );
    $Self->Is( $Metadata->{haushaltsjahr},  '2025',    'haushaltsjahr aus DF BeschaffungHaushaltsjahr' );
    $Self->Is( $Metadata->{inventarisierung}, 'true',  'inventarisierung aus DF BeschaffungInventarisierung' );
    $Self->Is( $Metadata->{betrag},         '1234,56', 'betrag aus DF BeschaffungRechnungsBetragBrutto' );
    $Self->Is( $Metadata->{zahlungspartner}, 'Testlieferant GmbH', 'zahlungspartner aus DF BeschaffungLieferant' );
    $Self->Is( $Metadata->{nutzer},         'Max Mustermann', 'nutzer aus DF BeschaffungNutzer' );
    $Self->Is( $Metadata->{raum},           'A.1.01',  'raum aus DF BeschaffungRaum' );
    $Self->Is( $Metadata->{klassifikation}, 'EDV',     'klassifikation aus DF BeschaffungKlassifikation' );
    $Self->Is( $Metadata->{hauptgeraet},    'PC-001',  'hauptgeraet aus DF BeschaffungHauptgeraet' );
    $Self->Is( $Metadata->{bemerkung},      'Rechnung XY vom 01.01.2025', 'bemerkung aus Artikel-Text' );
}

# ================================================================
# Test 5: _BuildMetadata respektiert Config-Overrides (Mapping + Static)
# ================================================================
{
    my %TestTicket = (
        TicketID                        => 99999,
        DynamicField_BeschaffungTitel   => 'STD',
        DynamicField_BeschaffungEinheit => 'OVR',
    );

    my $Metadata = $WebhookModule->_BuildMetadata(
        Ticket => \%TestTicket,
        Config => {
            MetadataMapping => { titel => 'BeschaffungEinheit' },
            MetadataStatic  => { haushaltsjahr => '2099', inventarisierung => 'true' },
        },
        LogObject => $Kernel::OM->Get('Kernel::System::Log'),
    );

    $Self->Is( $Metadata->{titel},            'OVR',  'MetadataMapping override greift' );
    $Self->Is( $Metadata->{haushaltsjahr},    '2099', 'MetadataStatic override greift' );
    $Self->Is( $Metadata->{inventarisierung}, 'true', 'MetadataStatic inventarisierung override greift' );
}

1;
