#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    unshift @INC, '/opt/znuny/Kernel/cpan-lib';
    unshift @INC, '/opt/znuny';
}

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => { LogPrefix => 'CreateDynamicFields' },
);

my $DFObject = $Kernel::OM->Get('Kernel::System::DynamicField');

# Get current max FieldOrder to append after existing fields
my $ExistingFields = $DFObject->DynamicFieldList(Valid => 0, ResultType => 'HASH');
my $MaxOrder = 0;
for my $ID (keys %{ $ExistingFields || {} }) {
    my $Field = $DFObject->DynamicFieldGet(ID => $ID);
    $MaxOrder = $Field->{FieldOrder} if $Field->{FieldOrder} > $MaxOrder;
}
my $Order = $MaxOrder;

my @Fields = (
    # --- Gruppe A: BANF-Felder ---
    {
        Name       => 'BeschaffungKostenstelle',
        Label      => 'KST / KTR',
        FieldType  => 'Text',
        Config     => { DefaultValue => '', RegExList => [] },
    },
    {
        Name       => 'BeschaffungKostentraeger',
        Label      => 'FB / Projekt',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungTitel',
        Label      => 'Titel',
        FieldType  => 'Text',
        Config     => {
            DefaultValue => '',
            RegExList    => [{ Value => '^(\d{1,5})?$', ErrorMessage => 'Bitte max. 5 Ziffern eingeben' }],
        },
    },
    {
        Name       => 'BeschaffungKapitel',
        Label      => 'Kapitel',
        FieldType  => 'Text',
        Config     => {
            DefaultValue => '',
            RegExList    => [{ Value => '^(\d{1,4})?$', ErrorMessage => 'Bitte max. 4 Ziffern eingeben' }],
        },
    },
    {
        Name       => 'BeschaffungAusgabenart',
        Label      => 'A-Art',
        FieldType  => 'Text',
        Config     => {
            DefaultValue => '',
            RegExList    => [{ Value => '^(\d{1,10})?$', ErrorMessage => 'Bitte max. 10 Ziffern eingeben' }],
        },
    },
    {
        Name       => 'BeschaffungKostenart',
        Label      => 'KOA',
        FieldType  => 'Text',
        Config     => {
            DefaultValue => '',
            RegExList    => [{ Value => '^(\d{1,5})?$', ErrorMessage => 'Bitte max. 5 Ziffern eingeben' }],
        },
    },
    {
        Name       => 'BeschaffungPositionsbeschreibung',
        Label      => 'Positionsbeschreibung',
        FieldType  => 'TextArea',
        Config     => { DefaultValue => '', Rows => 4, Cols => 50 },
    },
    {
        Name       => 'BeschaffungMenge',
        Label      => 'Menge',
        FieldType  => 'Text',
        Config     => { DefaultValue => '1' },
    },
    {
        Name       => 'BeschaffungEinheit',
        Label      => 'Einheit',
        FieldType  => 'Dropdown',
        Config     => {
            DefaultValue     => 'Stueck',
            PossibleNone     => 0,
            TranslatableValues => 0,
            PossibleValues   => {
                'Stueck'    => 'Stueck',
                'kg'        => 'kg',
                'Liter'     => 'Liter',
                'Meter'     => 'Meter',
                'Paket'     => 'Paket',
                'Lizenz'    => 'Lizenz',
                'Sonstiges' => 'Sonstiges',
            },
        },
    },
    {
        Name       => 'BeschaffungGeschaetzterWert',
        Label      => 'Geschaetzter Wert (EUR netto)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '', RegExList => [] },
    },
    {
        Name       => 'BeschaffungLieferant',
        Label      => 'Lieferant (Vorschlag)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungBedarfstermin',
        Label      => 'Bedarfstermin',
        FieldType  => 'Date',
        Config     => { DefaultValue => 0, YearsInPast => 0, YearsInFuture => 2, Link => '' },
    },
    # --- Gruppe B: Genehmigungs-Felder ---
    {
        Name       => 'BeschaffungGenehmigungsDatum',
        Label      => 'Freigabedatum',
        FieldType  => 'DateTime',
        Config     => { DefaultValue => 0, YearsInPast => 0, YearsInFuture => 2, Link => '' },
    },
    {
        Name       => 'BeschaffungGenehmigungskommentar',
        Label      => 'Genehmigungskommentar',
        FieldType  => 'TextArea',
        Config     => { DefaultValue => '', Rows => 3, Cols => 50 },
    },
    # --- Gruppe C: Bestellungs-Felder ---
    {
        Name       => 'BeschaffungBestellnummer',
        Label      => 'Bestellnummer (PO)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungLieferterminBestaetigt',
        Label      => 'Bestaetiger Liefertermin',
        FieldType  => 'Date',
        Config     => { DefaultValue => 0, YearsInPast => 0, YearsInFuture => 2, Link => '' },
    },
    # --- Gruppe D: Wareneingangs-Felder ---
    {
        Name       => 'BeschaffungLieferscheinNummer',
        Label      => 'Lieferscheinnummer',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungWareneingangsDatum',
        Label      => 'Wareneingangsdatum',
        FieldType  => 'Date',
        Config     => { DefaultValue => 0, YearsInPast => 1, YearsInFuture => 0, Link => '' },
    },
    {
        Name       => 'BeschaffungWareneingangsMangel',
        Label      => 'Maengelprotokoll',
        FieldType  => 'TextArea',
        Config     => { DefaultValue => 'Keine Maengel', Rows => 3, Cols => 50 },
    },
    # --- Gruppe E: Rechnungs-Felder ---
    {
        Name       => 'BeschaffungRechnungsnummer',
        Label      => 'Rechnungsnummer',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungRechnungsdatum',
        Label      => 'Rechnungsdatum',
        FieldType  => 'Date',
        Config     => { DefaultValue => 0, YearsInPast => 1, YearsInFuture => 0, Link => '' },
    },
    {
        Name       => 'BeschaffungRechnungsBetragBrutto',
        Label      => 'Rechnungsbetrag brutto',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungFestlegung',
        Label      => 'Festlegung / Huel',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungZahlungsziel',
        Label      => 'Zahlungsziel',
        FieldType  => 'Dropdown',
        Config     => {
            DefaultValue     => '30 Tage netto',
            PossibleNone     => 0,
            TranslatableValues => 0,
            PossibleValues   => {
                'Sofort'           => 'Sofort',
                '8 Tage 2% Skonto' => '8 Tage / 2% Skonto',
                '14 Tage netto'    => '14 Tage netto',
                '30 Tage netto'    => '30 Tage netto',
                '60 Tage netto'    => '60 Tage netto',
            },
        },
    },
    # --- Gruppe F: StampIt-/Kontierungsstempel-Felder ---
    # (Mapping siehe doc/map_znuny_stampit.md)
    {
        Name       => 'BeschaffungAnwendung',
        Label      => 'Anwendung (AW)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungHaushaltsjahr',
        Label      => 'Haushaltsjahr',
        FieldType  => 'Text',
        Config     => {
            DefaultValue => '',
            RegExList    => [{ Value => '^(\d{4})?$', ErrorMessage => 'Bitte vierstelliges Jahr eingeben' }],
        },
    },
    {
        Name       => 'BeschaffungInventarisierung',
        Label      => 'Inventarisierung',
        FieldType  => 'Dropdown',
        Config     => {
            DefaultValue       => 'false',
            PossibleNone       => 0,
            TranslatableValues => 0,
            PossibleValues     => {
                'false' => 'Nein',
                'true'  => 'Ja',
            },
        },
    },
    {
        Name       => 'BeschaffungNutzer',
        Label      => 'Nutzer (bei Inventarisierung)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungKlassifikation',
        Label      => 'Klassifikation (bei Inventarisierung)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungRaum',
        Label      => 'Raum (bei Inventarisierung)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
    {
        Name       => 'BeschaffungHauptgeraet',
        Label      => 'Hauptgeraet (bei Inventarisierung)',
        FieldType  => 'Text',
        Config     => { DefaultValue => '' },
    },
);

my ($created, $skipped, $errors) = (0, 0, 0);

for my $Field (@Fields) {
    my $Existing = $DFObject->DynamicFieldGet(Name => $Field->{Name});
    if ($Existing && $Existing->{ID}) {
        print "SKIP  '$Field->{Name}' (already exists, ID=$Existing->{ID})\n";
        $skipped++;
        next;
    }

    $Order++;
    my $ID = $DFObject->DynamicFieldAdd(
        Name       => $Field->{Name},
        Label      => $Field->{Label},
        FieldOrder => $Order,
        FieldType  => $Field->{FieldType},
        ObjectType => 'Ticket',
        Config     => $Field->{Config},
        ValidID    => 1,
        UserID     => 1,
    );

    if ($ID) {
        print "OK    '$Field->{Name}' ($Field->{FieldType}) created (ID=$ID, order=$Order)\n";
        $created++;
    } else {
        print "ERROR '$Field->{Name}' - DynamicFieldAdd failed\n";
        $errors++;
        $Order--;
    }
}

print "\n--- Summary: $created created, $skipped skipped, $errors errors ---\n";
exit($errors ? 1 : 0);
