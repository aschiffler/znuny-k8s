#!/usr/bin/perl
use strict;
use warnings;
BEGIN {
    unshift @INC, '/opt/znuny/Kernel/cpan-lib';
    unshift @INC, '/opt/znuny';
}

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => { LogPrefix => 'CreateStates' },
);

my $StateObject = $Kernel::OM->Get('Kernel::System::State');

my @States = (
    { Name => 'BANF-Entwurf',        TypeName => 'open',               Comment => 'Bestellanforderung erstellt (Entwurf)' },
    { Name => 'BANF-gesendet',        TypeName => 'pending reminder',   Comment => 'BANF zur Genehmigung eingereicht' },
    { Name => 'BANF-freigegeben',     TypeName => 'open',               Comment => 'BANF genehmigt - Bestellung kann ausgeloest werden' },
    { Name => 'BANF-abgelehnt',       TypeName => 'closed',             Comment => 'Bestellanforderung abgelehnt' },
    { Name => 'Bestellung-versendet', TypeName => 'pending reminder',   Comment => 'Purchase Order versandt - wartet auf Lieferung' },
    { Name => 'Lieferung-erhalten',   TypeName => 'open',               Comment => 'Wareneingang bestaetigt' },
    { Name => 'Rechnung-erhalten',    TypeName => 'open',               Comment => 'Rechnung eingegangen - Kontierung ausstehend' },
    { Name => 'Rechnung-kontiert',    TypeName => 'open',               Comment => 'Kontierung erfasst - Freigabe ausstehend' },
    { Name => 'Rechnung-freigegeben', TypeName => 'open',               Comment => 'Rechnung genehmigt - Zahlanweisung folgt' },
    { Name => 'Rechnung-abgelehnt',   TypeName => 'open',               Comment => 'Rechnung zurueckgewiesen - Klaerung erforderlich' },
    { Name => 'Rechnung-versendet',   TypeName => 'closed',             Comment => 'Beschaffungsprozess vollstaendig abgeschlossen' },
);

# Build TypeName -> TypeID map
my %StateTypeList  = $StateObject->StateTypeList(UserID => 1);
my %TypeIDByName   = reverse %StateTypeList;

print "Found state types: " . join(', ', sort values %StateTypeList) . "\n\n";

my ($created, $skipped, $errors) = (0, 0, 0);

for my $State (@States) {
    my %Existing = $StateObject->StateGet(Name => $State->{Name});
    if (%Existing && $Existing{ID}) {
        print "SKIP  '$State->{Name}' (already exists, ID=$Existing{ID})\n";
        $skipped++;
        next;
    }

    my $TypeID = $TypeIDByName{ $State->{TypeName} };
    if (!$TypeID) {
        print "ERROR '$State->{Name}' - unknown type '$State->{TypeName}'\n";
        $errors++;
        next;
    }

    my $StateID = $StateObject->StateAdd(
        Name    => $State->{Name},
        Comment => $State->{Comment},
        ValidID => 1,
        TypeID  => $TypeID,
        UserID  => 1,
    );

    if ($StateID) {
        print "OK    '$State->{Name}' created (ID=$StateID, type=$State->{TypeName})\n";
        $created++;
    } else {
        print "ERROR '$State->{Name}' - StateAdd failed\n";
        $errors++;
    }
}

print "\n--- Summary: $created created, $skipped skipped, $errors errors ---\n";
exit($errors ? 1 : 0);
