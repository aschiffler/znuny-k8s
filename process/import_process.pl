#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    unshift @INC, '/opt/znuny/Kernel/cpan-lib';
    unshift @INC, '/opt/znuny';
}

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => { LogPrefix => 'ImportProcess' },
);

my $ProcessObject        = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Process');
my $ActivityObject       = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Activity');
my $DialogObject         = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');
my $TransitionObject     = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Transition');
my $TAObject             = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::TransitionAction');
my $EntityObject         = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Entity');
my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');

# Active state EntityID is always S1 in Znuny
my $ActiveSEID = 'S1';
print "Active state EntityID: $ActiveSEID\n\n";

my ($ok, $skip, $err) = (0, 0, 0);

# Fields present in every activity dialog (Display=1 = visible/optional)
my %COMMON_FIELDS = (
    DynamicField_BeschaffungTitel       => { Display => 1, DefaultValue => '', DescriptionShort => 'Titel (max. 5 Stellen)',        DescriptionLong => '' },
    DynamicField_BeschaffungKapitel     => { Display => 1, DefaultValue => '', DescriptionShort => 'Kapitel (max. 4 Stellen)',      DescriptionLong => '' },
    DynamicField_BeschaffungAusgabenart => { Display => 1, DefaultValue => '', DescriptionShort => 'Ausgabenart (max. 10 Stellen)', DescriptionLong => '' },
    DynamicField_BeschaffungKostenart   => { Display => 1, DefaultValue => '', DescriptionShort => 'Kostenart / KOA (max. 5 Stellen)', DescriptionLong => '' },
);
my @COMMON_FIELD_ORDER = qw(
    DynamicField_BeschaffungTitel
    DynamicField_BeschaffungKapitel
    DynamicField_BeschaffungAusgabenart
    DynamicField_BeschaffungKostenart
);

sub merge_common {
    my ($config) = @_;
    $config->{Interface} //= ['AgentInterface'];
    for my $k (keys %COMMON_FIELDS) {
        $config->{Fields}{$k} //= $COMMON_FIELDS{$k};
    }
    my %in_order = map { $_ => 1 } @{ $config->{FieldOrder} };
    for my $k (@COMMON_FIELD_ORDER) {
        push @{ $config->{FieldOrder} }, $k unless $in_order{$k};
    }
    return $config;
}

sub log_result {
    my ($type, $name, $id) = @_;
    if    ($id && $id eq 'skip') { print "SKIP  $type '$name'\n"; $skip++ }
    elsif ($id)                  { print "OK    $type '$name' (ID=$id)\n"; $ok++ }
    else                         { print "ERROR $type '$name'\n"; $err++ }
}

# ============================================================
# ACTIVITY DIALOGS
# ============================================================

my @Dialogs = (
    {
        EntityID => 'ActivityDialog-BANF-Erstellen',
        Name     => 'BANF erstellen',
        Config   => {
            Interface        => ['CustomerInterface'],
            DescriptionShort => 'Neue Bestellanforderung erfassen',
            DescriptionLong  => 'Erfassen Sie alle Pflichtangaben fuer die Bestellanforderung.',
            Permission       => 'rw',
            RequiredLock     => 0,
            SubmitAdviceText => 'Die BANF wird nach dem Speichern zur Genehmigung eingereicht.',
            SubmitButtonText => 'BANF erstellen',
            FieldOrder       => [qw(
                Title
                DynamicField_BeschaffungKostenstelle
                DynamicField_BeschaffungKostentraeger
                DynamicField_BeschaffungPositionsbeschreibung
                DynamicField_BeschaffungMenge
                DynamicField_BeschaffungEinheit
                DynamicField_BeschaffungGeschaetzterWert
                DynamicField_BeschaffungLieferant
                DynamicField_BeschaffungBedarfstermin
                State Queue
            )],
            Fields => {
                Title                                        => { Display => 2, DefaultValue => '', DescriptionShort => 'Betreff', DescriptionLong => '' },
                Queue                                        => { Display => 0, DefaultValue => 'Beschaffung::BANF', DescriptionShort => 'Queue', DescriptionLong => '' },
                State                                        => { Display => 0, DefaultValue => 'BANF-Entwurf', DescriptionShort => 'Status', DescriptionLong => '' },
                DynamicField_BeschaffungKostenstelle         => { Display => 2, DefaultValue => '', DescriptionShort => 'KST / KTR', DescriptionLong => '' },
                DynamicField_BeschaffungKostentraeger        => { Display => 1, DefaultValue => '', DescriptionShort => 'FB / Projekt', DescriptionLong => '' },
                DynamicField_BeschaffungPositionsbeschreibung => { Display => 2, DefaultValue => '', DescriptionShort => 'Was soll beschafft werden?', DescriptionLong => '' },
                DynamicField_BeschaffungMenge                => { Display => 2, DefaultValue => '', DescriptionShort => 'Menge', DescriptionLong => '' },
                DynamicField_BeschaffungEinheit              => { Display => 2, DefaultValue => '', DescriptionShort => 'Einheit', DescriptionLong => '' },
                DynamicField_BeschaffungGeschaetzterWert     => { Display => 2, DefaultValue => '', DescriptionShort => 'Geschaetzter Wert EUR netto', DescriptionLong => '' },
                DynamicField_BeschaffungLieferant            => { Display => 1, DefaultValue => '', DescriptionShort => 'Lieferant (optional)', DescriptionLong => '' },
                DynamicField_BeschaffungBedarfstermin        => { Display => 1, DefaultValue => '', DescriptionShort => 'Gewuenschter Liefertermin', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-BANF-Genehmigung',
        Name     => 'BANF genehmigen oder ablehnen',
        Config   => {
            DescriptionShort => 'Pruefe und entscheide ueber die Bestellanforderung',
            DescriptionLong  => 'Waehlen Sie freigegeben oder abgelehnt und tragen Sie Ihren Kommentar ein.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Entscheidung speichern',
            FieldOrder       => [qw(
                State Queue
                DynamicField_BeschaffungGenehmigungsDatum
                DynamicField_BeschaffungGenehmigungskommentar
            )],
            Fields => {
                Queue                                        => { Display => 0, DefaultValue => 'Beschaffung::Genehmigung', DescriptionShort => '', DescriptionLong => '' },
                State                                        => { Display => 2, DefaultValue => 'BANF-freigegeben', DescriptionShort => 'Freigabe oder Ablehnung', DescriptionLong => '' },
                DynamicField_BeschaffungGenehmigungsDatum    => { Display => 2, DefaultValue => '', DescriptionShort => 'Datum der Entscheidung', DescriptionLong => '' },
                DynamicField_BeschaffungGenehmigungskommentar => { Display => 1, DefaultValue => '', DescriptionShort => 'Kommentar', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Bestellung-Erstellen',
        Name     => 'Bestellung versenden',
        Config   => {
            Interface        => ['AgentInterface', 'CustomerInterface'],
            DescriptionShort => 'Bestelldaten erfassen und PO versenden',
            DescriptionLong  => 'Erfassen Sie die Bestellnummer und den bestaedigten Liefertermin.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Bestellung versenden',
            FieldOrder       => [qw(
                DynamicField_BeschaffungBestellnummer
                DynamicField_BeschaffungLieferterminBestaetigt
                State Queue
            )],
            Fields => {
                Queue                                         => { Display => 0, DefaultValue => 'Beschaffung::Bestellung', DescriptionShort => '', DescriptionLong => '' },
                State                                         => { Display => 0, DefaultValue => 'Bestellung-versendet', DescriptionShort => '', DescriptionLong => '' },
                DynamicField_BeschaffungBestellnummer         => { Display => 2, DefaultValue => '', DescriptionShort => 'PO-Nummer', DescriptionLong => '' },
                DynamicField_BeschaffungLieferterminBestaetigt => { Display => 1, DefaultValue => '', DescriptionShort => 'Bestaedigter Liefertermin', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Wareneingang-Erfassen',
        Name     => 'Wareneingang erfassen',
        Config   => {
            Interface        => ['AgentInterface', 'CustomerInterface'],
            DescriptionShort => 'Empfang der Lieferung bestaetigen',
            DescriptionLong  => 'Tragen Sie Lieferscheinnummer, Eingangsdatum, etwaige Maengel und – '
                              . 'falls erforderlich – die Inventarisierungsdaten ein.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Wareneingang bestaetigen',
            FieldOrder       => [qw(
                DynamicField_BeschaffungLieferscheinNummer
                DynamicField_BeschaffungWareneingangsDatum
                DynamicField_BeschaffungWareneingangsMangel
                DynamicField_BeschaffungInventarisierung
                DynamicField_BeschaffungHauptgeraet
                DynamicField_BeschaffungNutzer
                DynamicField_BeschaffungRaum
                DynamicField_BeschaffungKlassifikation
                State Queue
            )],
            Fields => {
                Queue                                      => { Display => 0, DefaultValue => 'Beschaffung::Wareneingang', DescriptionShort => '', DescriptionLong => '' },
                State                                      => { Display => 0, DefaultValue => 'Lieferung-erhalten', DescriptionShort => '', DescriptionLong => '' },
                DynamicField_BeschaffungLieferscheinNummer => { Display => 2, DefaultValue => '', DescriptionShort => 'Lieferscheinnummer', DescriptionLong => '' },
                DynamicField_BeschaffungWareneingangsDatum => { Display => 2, DefaultValue => '', DescriptionShort => 'Datum des Wareneingangs', DescriptionLong => '' },
                DynamicField_BeschaffungWareneingangsMangel => { Display => 1, DefaultValue => '', DescriptionShort => 'Maengelprotokoll', DescriptionLong => '' },
                DynamicField_BeschaffungInventarisierung   => { Display => 2, DefaultValue => 'false', DescriptionShort => 'Inventarisierung erforderlich?', DescriptionLong => 'Bei "Ja" bitte die folgenden Geraetedaten ausfuellen.' },
                DynamicField_BeschaffungHauptgeraet        => { Display => 1, DefaultValue => '', DescriptionShort => 'Hauptgeraet (bei Inventarisierung)', DescriptionLong => '' },
                DynamicField_BeschaffungNutzer             => { Display => 1, DefaultValue => '', DescriptionShort => 'Nutzer (bei Inventarisierung)', DescriptionLong => '' },
                DynamicField_BeschaffungRaum               => { Display => 1, DefaultValue => '', DescriptionShort => 'Raum (bei Inventarisierung)', DescriptionLong => '' },
                DynamicField_BeschaffungKlassifikation     => { Display => 1, DefaultValue => '', DescriptionShort => 'Klassifikation (bei Inventarisierung)', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Rechnung-Erfassen',
        Name     => 'Rechnung erfassen',
        Config   => {
            Interface        => ['AgentInterface', 'CustomerInterface'],
            DescriptionShort => 'Eingangsrechnung registrieren',
            DescriptionLong  => 'Erfassen Sie Rechnungsnummer, Datum und Betrag.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Rechnung erfassen',
            FieldOrder       => [qw(
                Article
                DynamicField_BeschaffungRechnungsnummer
                DynamicField_BeschaffungRechnungsdatum
                DynamicField_BeschaffungRechnungsBetragBrutto
                DynamicField_BeschaffungZahlungsziel
                State Queue
            )],
            Fields => {
                Article => {
                    Display          => 1,
                    DefaultValue     => '',
                    DescriptionShort => 'Bitte Rechnung als PDF anhängen',
                    DescriptionLong  => 'Bitte Rechnung als PDF anhängen',
                    Config => {
                        Body                     => '',
                        CommunicationChannel     => 'Internal',
                        IsVisibleForCustomer     => 1,
                        StandardTemplateAutoFill => 0,
                        StandardTemplateID       => [],
                        Subject                  => 'Rechnungseingang',
                        TimeUnits                => 2,
                    },
                },
                Queue                                      => { Display => 0, DefaultValue => 'Beschaffung::Rechnungspruefung', DescriptionShort => '', DescriptionLong => '' },
                State                                      => { Display => 0, DefaultValue => 'Rechnung-erhalten', DescriptionShort => '', DescriptionLong => '' },
                DynamicField_BeschaffungRechnungsnummer    => { Display => 2, DefaultValue => '', DescriptionShort => 'Rechnungsnummer', DescriptionLong => '' },
                DynamicField_BeschaffungRechnungsdatum     => { Display => 2, DefaultValue => '', DescriptionShort => 'Rechnungsdatum', DescriptionLong => '' },
                DynamicField_BeschaffungRechnungsBetragBrutto => { Display => 2, DefaultValue => '', DescriptionShort => 'Rechnungsbetrag brutto EUR', DescriptionLong => '' },
                DynamicField_BeschaffungZahlungsziel       => { Display => 1, DefaultValue => '', DescriptionShort => 'Zahlungsziel', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Rechnung-Kontieren',
        Name     => 'Rechnung kontieren',
        Config   => {
            Interface        => ['AgentInterface', 'CustomerInterface'],
            DescriptionShort => 'Buchhalterische Kontierung erfassen',
            DescriptionLong  => 'Weisen Sie Sachkonto, Kostenstelle und ggf. PSP zu.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Kontierung speichern',
            FieldOrder       => [qw(
                Attachments
                DynamicField_BeschaffungSachkonto
                DynamicField_BeschaffungKostenstelle
                DynamicField_BeschaffungKostentraeger
                State
            )],
            Fields => {
                Attachments                           => { Display => 1, DefaultValue => '', DescriptionShort => 'Unterzeichnete PDF', DescriptionLong => 'Unterzeichnete PDF' },
                State                                 => { Display => 0, DefaultValue => 'Rechnung-kontiert', DescriptionShort => '', DescriptionLong => '' },
                DynamicField_BeschaffungSachkonto     => { Display => 2, DefaultValue => '', DescriptionShort => 'Sachkonto fuer die Buchung', DescriptionLong => '' },
                DynamicField_BeschaffungKostenstelle  => { Display => 1, DefaultValue => '', DescriptionShort => 'KST / KTR', DescriptionLong => '' },
                DynamicField_BeschaffungKostentraeger => { Display => 1, DefaultValue => '', DescriptionShort => 'FB / Projekt (optional)', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Rechnung-Freigeben',
        Name     => 'Rechnung freigeben oder ablehnen',
        Config   => {
            DescriptionShort => 'Sachliche und rechnerische Pruefung abschliessen',
            DescriptionLong  => 'Geben Sie die Rechnung frei oder weisen Sie sie zur Klaerung zurueck.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Entscheidung speichern',
            FieldOrder       => [qw(
                State
                DynamicField_BeschaffungGenehmigungskommentar
            )],
            Fields => {
                State                                        => { Display => 2, DefaultValue => 'Rechnung-freigegeben', DescriptionShort => 'Freigabe oder Ablehnung', DescriptionLong => '' },
                DynamicField_BeschaffungGenehmigungskommentar => { Display => 1, DefaultValue => '', DescriptionShort => 'Kommentar (Pflichtfeld bei Ablehnung)', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Zahlanweisung-Versenden',
        Name     => 'Zahlanweisung versenden',
        Config   => {
            DescriptionShort => 'Zahlungsauftrag erteilen und Vorgang abschliessen',
            DescriptionLong  => 'Bestaetigen Sie die Uebermittlung der Zahlanweisung.',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Zahlanweisung versenden und Vorgang schliessen',
            FieldOrder       => [qw(State)],
            Fields => {
                State => { Display => 0, DefaultValue => 'Rechnung-versendet', DescriptionShort => '', DescriptionLong => '' },
            },
        },
    },
    {
        EntityID => 'ActivityDialog-Rechnung-Klaerung',
        Name     => 'Rechnung klaeren und erneut einreichen',
        Config   => {
            DescriptionShort => 'Klaerung des Ablehnungsgrunds und erneute Einreichung',
            DescriptionLong  => '',
            Permission       => 'rw',
            RequiredLock     => 1,
            SubmitAdviceText => '',
            SubmitButtonText => 'Rechnung erneut einreichen',
            FieldOrder       => [qw(DynamicField_BeschaffungGenehmigungskommentar State)],
            Fields => {
                State                                        => { Display => 0, DefaultValue => 'Rechnung-erhalten', DescriptionShort => '', DescriptionLong => '' },
                DynamicField_BeschaffungGenehmigungskommentar => { Display => 2, DefaultValue => '', DescriptionShort => 'Klaerungsnotiz', DescriptionLong => '' },
            },
        },
    },
);

print "=== Activity Dialogs ===\n";
for my $D (@Dialogs) {
    merge_common($D->{Config});
    my $existing = $DialogObject->ActivityDialogGet(EntityID => $D->{EntityID}, UserID => 1);
    if ($existing && $existing->{ID}) {
        my $ok = $DialogObject->ActivityDialogUpdate(
            ID       => $existing->{ID},
            EntityID => $D->{EntityID},
            Name     => $D->{Name},
            Config   => $D->{Config},
            UserID   => 1,
        );
        log_result('Dialog (updated)', $D->{Name}, $ok ? $existing->{ID} : undef);
        next;
    }
    my $id = $DialogObject->ActivityDialogAdd(
        EntityID => $D->{EntityID},
        Name     => $D->{Name},
        Config   => $D->{Config},
        UserID   => 1,
    );
    log_result('Dialog', $D->{Name}, $id);
}

# ============================================================
# TRANSITIONS
# ============================================================
my @Transitions = (
    {
        EntityID => 'Transition-BANF-Senden',
        Name     => 'BANF senden',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => {
                    Type   => 'and',
                    Fields => {
                        DynamicField_BeschaffungKostenstelle          => { Type => 'Regexp', Match => '.+' },
                        DynamicField_BeschaffungPositionsbeschreibung => { Type => 'Regexp', Match => '.+' },
                        DynamicField_BeschaffungMenge                 => { Type => 'Regexp', Match => '.+' },
                        State => { Type => 'String', Match => 'BANF-Entwurf' },
                    },
                },
            },
        },
    },
    {
        EntityID => 'Transition-BANF-Freigegeben',
        Name     => 'BANF freigegeben',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => { Type => 'and', Fields => { State => { Type => 'String', Match => 'BANF-freigegeben' } } },
            },
        },
    },
    {
        EntityID => 'Transition-BANF-Abgelehnt',
        Name     => 'BANF abgelehnt',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => { Type => 'and', Fields => { State => { Type => 'String', Match => 'BANF-abgelehnt' } } },
            },
        },
    },
    {
        EntityID => 'Transition-Bestellung-Versenden',
        Name     => 'Bestellung versenden',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => {
                    Type   => 'and',
                    Fields => {
                        DynamicField_BeschaffungBestellnummer => { Type => 'Regexp', Match => '.+' },
                        State => { Type => 'String', Match => 'Bestellung-versendet' },
                    },
                },
            },
        },
    },
    {
        EntityID => 'Transition-Lieferung-Erhalten',
        Name     => 'Lieferung erhalten',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => {
                    Type   => 'and',
                    Fields => {
                        DynamicField_BeschaffungLieferscheinNummer => { Type => 'Regexp', Match => '.+' },
                        State => { Type => 'String', Match => 'Lieferung-erhalten' },
                    },
                },
            },
        },
    },
    {
        EntityID => 'Transition-Rechnung-Erhalten',
        Name     => 'Rechnung erhalten',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => {
                    Type   => 'and',
                    Fields => {
                        DynamicField_BeschaffungRechnungsnummer => { Type => 'Regexp', Match => '.+' },
                        State => { Type => 'String', Match => 'Rechnung-erhalten' },
                    },
                },
            },
        },
    },
    {
        EntityID => 'Transition-Rechnung-Kontiert',
        Name     => 'Rechnung kontiert',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => {
                    Type   => 'and',
                    Fields => {
                        DynamicField_BeschaffungSachkonto => { Type => 'Regexp', Match => '.+' },
                        State => { Type => 'String', Match => 'Rechnung-kontiert' },
                    },
                },
            },
        },
    },
    {
        EntityID => 'Transition-Rechnung-Freigegeben',
        Name     => 'Rechnung freigegeben',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => { Type => 'and', Fields => { State => { Type => 'String', Match => 'Rechnung-freigegeben' } } },
            },
        },
    },
    {
        EntityID => 'Transition-Rechnung-Abgelehnt',
        Name     => 'Rechnung abgelehnt',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => { Type => 'and', Fields => { State => { Type => 'String', Match => 'Rechnung-abgelehnt' } } },
            },
        },
    },
    {
        EntityID => 'Transition-Rechnung-Erneut-Einreichen',
        Name     => 'Rechnung erneut einreichen',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => {
                    Type   => 'and',
                    Fields => {
                        DynamicField_BeschaffungGenehmigungskommentar => { Type => 'Regexp', Match => '.+' },
                        State => { Type => 'String', Match => 'Rechnung-erhalten' },
                    },
                },
            },
        },
    },
    {
        EntityID => 'Transition-Rechnung-Versendet',
        Name     => 'Zahlanweisung versendet - Abschluss',
        Config   => {
            ConditionLinking => 'and',
            Condition => {
                Cond1 => { Type => 'and', Fields => { State => { Type => 'String', Match => 'Rechnung-versendet' } } },
            },
        },
    },
);

print "\n=== Transitions ===\n";
for my $T (@Transitions) {
    my $existing = $TransitionObject->TransitionGet(EntityID => $T->{EntityID}, UserID => 1);
    if ($existing && $existing->{ID}) {
        my $ok = $TransitionObject->TransitionUpdate(
            ID       => $existing->{ID},
            EntityID => $T->{EntityID},
            Name     => $T->{Name},
            Config   => $T->{Config},
            UserID   => 1,
        );
        log_result('Transition (updated)', $T->{Name}, $ok ? $existing->{ID} : undef);
        next;
    }
    my $id = $TransitionObject->TransitionAdd(
        EntityID => $T->{EntityID},
        Name     => $T->{Name},
        Config   => $T->{Config},
        UserID   => 1,
    );
    log_result('Transition', $T->{Name}, $id);
}

# ============================================================
# ACTIVITIES
# ============================================================
my @Activities = (
    { EntityID => 'Activity-BANF-Erstellen',         Name => 'BANF erstellen',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-BANF-Erstellen' } } },
    { EntityID => 'Activity-BANF-Gesendet',           Name => 'BANF gesendet - wartet auf Freigabe',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-BANF-Genehmigung' } } },
    { EntityID => 'Activity-BANF-Freigegeben',        Name => 'BANF freigegeben - Bestellung ausloesen',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Bestellung-Erstellen' } } },
    { EntityID => 'Activity-BANF-Abgelehnt',          Name => 'BANF abgelehnt',
      Config   => { ActivityDialog => {} } },
    { EntityID => 'Activity-Bestellung-Versendet',    Name => 'Bestellung versendet - wartet auf Lieferung',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Wareneingang-Erfassen' } } },
    { EntityID => 'Activity-Lieferung-Erhalten',      Name => 'Lieferung erhalten - wartet auf Rechnung',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Rechnung-Erfassen' } } },
    { EntityID => 'Activity-Rechnung-Erhalten',       Name => 'Rechnung erhalten - Unterschrift / Kontierung ausstehend',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Rechnung-Kontieren' } } },
    { EntityID => 'Activity-Rechnung-Kontiert',       Name => 'Rechnung kontiert - Freigabe ausstehend',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Rechnung-Freigeben' } } },
    { EntityID => 'Activity-Rechnung-Freigegeben',    Name => 'Rechnung freigegeben - Zahlanweisung erstellen',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Zahlanweisung-Versenden' } } },
    { EntityID => 'Activity-Rechnung-Abgelehnt',      Name => 'Rechnung abgelehnt - Klaerung erforderlich',
      Config   => { ActivityDialog => { 1 => 'ActivityDialog-Rechnung-Klaerung' } } },
    { EntityID => 'Activity-Rechnung-Versendet',      Name => 'Beschaffung abgeschlossen',
      Config   => { ActivityDialog => {} } },
);

# ============================================================
# TRANSITION ACTIONS
# ============================================================
my $MOD_STATE   = 'Kernel::System::ProcessManagement::TransitionAction::TicketStateSet';
my $MOD_QUEUE   = 'Kernel::System::ProcessManagement::TransitionAction::TicketQueueSet';

my @TransitionActions = (
    { EntityID => 'TA-State-BANFGesendet',       Name => 'Set State: BANF-gesendet',
      Config   => { Module => $MOD_STATE, Config => { State => 'BANF-gesendet',       UserID => '1' } } },
    { EntityID => 'TA-State-BANFFreigegeben',     Name => 'Set State: BANF-freigegeben',
      Config   => { Module => $MOD_STATE, Config => { State => 'BANF-freigegeben',     UserID => '1' } } },
    { EntityID => 'TA-State-BANFAbgelehnt',       Name => 'Set State: BANF-abgelehnt',
      Config   => { Module => $MOD_STATE, Config => { State => 'BANF-abgelehnt',       UserID => '1' } } },
    { EntityID => 'TA-State-BestellungVersendet', Name => 'Set State: Bestellung-versendet',
      Config   => { Module => $MOD_STATE, Config => { State => 'Bestellung-versendet', UserID => '1' } } },
    { EntityID => 'TA-State-LieferungErhalten',   Name => 'Set State: Lieferung-erhalten',
      Config   => { Module => $MOD_STATE, Config => { State => 'Lieferung-erhalten',   UserID => '1' } } },
    { EntityID => 'TA-State-RechnungErhalten',    Name => 'Set State: Rechnung-erhalten',
      Config   => { Module => $MOD_STATE, Config => { State => 'Rechnung-erhalten',    UserID => '1' } } },
    { EntityID => 'TA-State-RechnungKontiert',    Name => 'Set State: Rechnung-kontiert',
      Config   => { Module => $MOD_STATE, Config => { State => 'Rechnung-kontiert',    UserID => '1' } } },
    { EntityID => 'TA-State-RechnungFreigegeben', Name => 'Set State: Rechnung-freigegeben',
      Config   => { Module => $MOD_STATE, Config => { State => 'Rechnung-freigegeben', UserID => '1' } } },
    { EntityID => 'TA-State-RechnungAbgelehnt',   Name => 'Set State: Rechnung-abgelehnt',
      Config   => { Module => $MOD_STATE, Config => { State => 'Rechnung-abgelehnt',   UserID => '1' } } },
    { EntityID => 'TA-State-RechnungVersendet',   Name => 'Set State: Rechnung-versendet',
      Config   => { Module => $MOD_STATE, Config => { State => 'Rechnung-versendet',   UserID => '1' } } },
    { EntityID => 'TA-Queue-BANF',                Name => 'Move to: Beschaffung::BANF',
      Config   => { Module => $MOD_QUEUE, Config => { Queue => 'Beschaffung::BANF',               UserID => '1' } } },
    { EntityID => 'TA-Queue-Genehmigung',         Name => 'Move to: Beschaffung::Genehmigung',
      Config   => { Module => $MOD_QUEUE, Config => { Queue => 'Beschaffung::Genehmigung',        UserID => '1' } } },
    { EntityID => 'TA-Queue-Bestellung',          Name => 'Move to: Beschaffung::Bestellung',
      Config   => { Module => $MOD_QUEUE, Config => { Queue => 'Beschaffung::Bestellung',         UserID => '1' } } },
    { EntityID => 'TA-Queue-Wareneingang',        Name => 'Move to: Beschaffung::Wareneingang',
      Config   => { Module => $MOD_QUEUE, Config => { Queue => 'Beschaffung::Wareneingang',       UserID => '1' } } },
    { EntityID => 'TA-Queue-Rechnungspruefung',   Name => 'Move to: Beschaffung::Rechnungspruefung',
      Config   => { Module => $MOD_QUEUE, Config => { Queue => 'Beschaffung::Rechnungspruefung',  UserID => '1' } } },
);

print "\n=== Transition Actions ===\n";
for my $TA (@TransitionActions) {
    my $existing = $TAObject->TransitionActionGet(EntityID => $TA->{EntityID}, UserID => 1);
    if ($existing && $existing->{ID}) {
        my $ok = $TAObject->TransitionActionUpdate(
            ID       => $existing->{ID},
            EntityID => $TA->{EntityID},
            Name     => $TA->{Name},
            Config   => $TA->{Config},
            UserID   => 1,
        );
        log_result('TA (updated)', $TA->{Name}, $ok ? $existing->{ID} : undef);
        next;
    }
    my $id = $TAObject->TransitionActionAdd(
        EntityID => $TA->{EntityID},
        Name     => $TA->{Name},
        Config   => $TA->{Config},
        UserID   => 1,
    );
    log_result('TA', $TA->{Name}, $id);
}

print "\n=== Activities ===\n";
for my $A (@Activities) {
    my $existing = $ActivityObject->ActivityGet(EntityID => $A->{EntityID}, UserID => 1);
    if ($existing && $existing->{ID}) {
        my $ok = $ActivityObject->ActivityUpdate(
            ID       => $existing->{ID},
            EntityID => $A->{EntityID},
            Name     => $A->{Name},
            Config   => $A->{Config},
            UserID   => 1,
        );
        log_result('Activity (updated)', $A->{Name}, $ok ? $existing->{ID} : undef);
        next;
    }
    my $id = $ActivityObject->ActivityAdd(
        EntityID => $A->{EntityID},
        Name     => $A->{Name},
        Config   => $A->{Config},
        UserID   => 1,
    );
    log_result('Activity', $A->{Name}, $id);
}

# ============================================================
# PROCESS
# ============================================================
print "\n=== Process ===\n";

my $existingProcess = $ProcessObject->ProcessGet(EntityID => 'Process-Beschaffung-001', UserID => 1) // {};
my $processLayout = {
    'Activity-BANF-Erstellen'      => { left => 100,  top => 100 },
    'Activity-BANF-Gesendet'       => { left => 300,  top => 100 },
    'Activity-BANF-Freigegeben'    => { left => 500,  top => 100 },
    'Activity-BANF-Abgelehnt'      => { left => 300,  top => 300 },
    'Activity-Bestellung-Versendet' => { left => 700, top => 100 },
    'Activity-Lieferung-Erhalten'  => { left => 900,  top => 100 },
    'Activity-Rechnung-Erhalten'   => { left => 1100, top => 100 },
    'Activity-Rechnung-Kontiert'   => { left => 1300, top => 100 },
    'Activity-Rechnung-Freigegeben' => { left => 1500, top => 100 },
    'Activity-Rechnung-Abgelehnt'  => { left => 1300, top => 300 },
    'Activity-Rechnung-Versendet'  => { left => 1700, top => 100 },
};
my $processConfig = {
    Description      => 'Elektronischer Beschaffungsprozess (Purchase-to-Pay)',
    StartActivity    => 'Activity-BANF-Erstellen',
    StartActivityDialog => 'ActivityDialog-BANF-Erstellen',
    Path => {
        'Activity-BANF-Erstellen' => {
            'Transition-BANF-Senden' => {
                ActivityEntityID => 'Activity-BANF-Gesendet',
                TransitionAction => ['TA-State-BANFGesendet', 'TA-Queue-Genehmigung'],
            },
        },
        'Activity-BANF-Gesendet' => {
            'Transition-BANF-Freigegeben' => {
                ActivityEntityID => 'Activity-BANF-Freigegeben',
                TransitionAction => ['TA-State-BANFFreigegeben', 'TA-Queue-Bestellung'],
            },
            'Transition-BANF-Abgelehnt' => {
                ActivityEntityID => 'Activity-BANF-Abgelehnt',
                TransitionAction => ['TA-State-BANFAbgelehnt', 'TA-Queue-BANF'],
            },
        },
        'Activity-BANF-Freigegeben' => {
            'Transition-Bestellung-Versenden' => {
                ActivityEntityID => 'Activity-Bestellung-Versendet',
                TransitionAction => ['TA-State-BestellungVersendet', 'TA-Queue-Wareneingang'],
            },
        },
        'Activity-Bestellung-Versendet' => {
            'Transition-Lieferung-Erhalten' => {
                ActivityEntityID => 'Activity-Lieferung-Erhalten',
                TransitionAction => ['TA-State-LieferungErhalten', 'TA-Queue-Rechnungspruefung'],
            },
        },
        'Activity-Lieferung-Erhalten' => {
            'Transition-Rechnung-Erhalten' => {
                ActivityEntityID => 'Activity-Rechnung-Erhalten',
                TransitionAction => ['TA-State-RechnungErhalten', 'TA-Queue-Rechnungspruefung'],
            },
        },
        'Activity-Rechnung-Erhalten' => {
            'Transition-Rechnung-Kontiert' => {
                ActivityEntityID => 'Activity-Rechnung-Kontiert',
                TransitionAction => ['TA-State-RechnungKontiert', 'TA-Queue-Rechnungspruefung'],
            },
        },
        'Activity-Rechnung-Kontiert' => {
            'Transition-Rechnung-Freigegeben' => {
                ActivityEntityID => 'Activity-Rechnung-Freigegeben',
                TransitionAction => ['TA-State-RechnungFreigegeben', 'TA-Queue-Rechnungspruefung'],
            },
            'Transition-Rechnung-Abgelehnt' => {
                ActivityEntityID => 'Activity-Rechnung-Abgelehnt',
                TransitionAction => ['TA-State-RechnungAbgelehnt', 'TA-Queue-Rechnungspruefung'],
            },
        },
        'Activity-Rechnung-Freigegeben' => {
            'Transition-Rechnung-Versendet' => {
                ActivityEntityID => 'Activity-Rechnung-Versendet',
                TransitionAction => ['TA-State-RechnungVersendet', 'TA-Queue-Rechnungspruefung'],
            },
        },
        'Activity-Rechnung-Abgelehnt' => {
            'Transition-Rechnung-Erneut-Einreichen' => {
                ActivityEntityID => 'Activity-Rechnung-Erhalten',
                TransitionAction => ['TA-State-RechnungErhalten', 'TA-Queue-Rechnungspruefung'],
            },
        },
        'Activity-BANF-Abgelehnt'     => {},
        'Activity-Rechnung-Versendet' => {},
    },
};
if ($existingProcess && $existingProcess->{ID}) {
    my $ok = $ProcessObject->ProcessUpdate(
        ID            => $existingProcess->{ID},
        EntityID      => 'Process-Beschaffung-001',
        Name          => 'Beschaffungsprozess',
        StateEntityID => $ActiveSEID,
        Layout        => $processLayout,
        Config        => $processConfig,
        UserID        => 1,
    );
    log_result('Process (updated)', 'Beschaffungsprozess', $ok ? $existingProcess->{ID} : undef);
} else {
    my $ProcessID = $ProcessObject->ProcessAdd(
        EntityID      => 'Process-Beschaffung-001',
        Name          => 'Beschaffungsprozess',
        StateEntityID => $ActiveSEID,
        Layout        => $processLayout,
        Config        => $processConfig,
        UserID        => 1,
    );
    log_result('Process', 'Beschaffungsprozess', $ProcessID);
}

# ============================================================
# ACLs
# ============================================================
my $ACLObject = $Kernel::OM->Get('Kernel::System::ACL::DB::ACL');

my @ACLs = (
    {
        Name           => 'ACL-Process-BANF-Genehmigung-States',
        Comment        => '',
        Description    => '',
        StopAfterMatch => 0,
        ValidID        => 1,
        ConfigMatch    => {
            Properties => {
                Process => {
                    ActivityEntityID => ['Activity-BANF-Gesendet'],
                },
            },
        },
        ConfigChange => {
            Possible => {
                Ticket => {
                    State => ['BANF-freigegeben', 'BANF-abgelehnt'],
                },
            },
        },
    },
    {
        Name           => 'ACL-Process-Rechnung-Freigabe-States',
        Comment        => '',
        Description    => '',
        StopAfterMatch => 0,
        ValidID        => 1,
        ConfigMatch    => {
            Properties => {
                Process => {
                    ActivityEntityID => ['Activity-Rechnung-Kontiert'],
                },
            },
        },
        ConfigChange => {
            Possible => {
                Ticket => {
                    State => ['Rechnung-freigegeben', 'Rechnung-abgelehnt'],
                },
            },
        },
    },
);

print "\n=== ACLs ===\n";
for my $ACL (@ACLs) {
    my $existing = $ACLObject->ACLGet(Name => $ACL->{Name}, UserID => 1);
    if ($existing && $existing->{ID}) {
        my $ok = $ACLObject->ACLUpdate(
            %{$ACL},
            ID     => $existing->{ID},
            UserID => 1,
        );
        log_result('ACL (updated)', $ACL->{Name}, $ok ? $existing->{ID} : undef);
    } else {
        my $id = $ACLObject->ACLAdd(
            %{$ACL},
            UserID => 1,
        );
        log_result('ACL', $ACL->{Name}, $id);
    }
}

print "\n=== Deploying ACLs ===\n";
my $ACLLocation = $ConfigObject->Get('Home') . '/Kernel/Config/Files/ZZZACL.pm';
my $ACLDump = $ACLObject->ACLDump(
    ResultType => 'FILE',
    Location   => $ACLLocation,
    UserID     => 1,
);
if ($ACLDump) {
    print "OK    ACL config written to $ACLLocation\n";
} else {
    print "ERROR ACLDump failed - please deploy ACLs in the admin UI\n";
    $err++;
}

# ============================================================
# DEPLOY (synchronize) - same as clicking "Synchronize all Processes" in the UI
# ============================================================
print "\n=== Deploying process configuration ===\n";
my $Location    = $ConfigObject->Get('Home') . '/Kernel/Config/Files/ZZZProcessManagement.pm';
my $ProcessDump = $ProcessObject->ProcessDump(
    ResultType => 'FILE',
    Location   => $Location,
    UserID     => 1,
);
if ($ProcessDump) {
    print "OK    Process config written to $Location\n";
    my $Purged = $EntityObject->EntitySyncStatePurge(UserID => 1);
    if ($Purged) {
        print "OK    Entity sync state purged\n";
    } else {
        print "WARN  EntitySyncStatePurge failed - try 'Synchronize all Processes' in the UI\n";
    }
} else {
    print "ERROR ProcessDump failed - please click 'Synchronize all Processes' in the admin UI\n";
}

print "\n--- Summary: $ok created, $skip skipped, $err errors ---\n";
exit($err ? 1 : 0);
