#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    unshift @INC, '/opt/znuny/Kernel/cpan-lib';
    unshift @INC, '/opt/znuny';
}

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => { LogPrefix => 'CreateQueues' },
);

my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

# Resolve group IDs by name so the script is not hard-coded to specific IDs
my %GroupList    = $GroupObject->GroupList(Valid => 1);
my %GroupByName  = reverse %GroupList;
my $UsersGroupID = $GroupByName{users} // 1;
my $AdminGroupID = $GroupByName{admin} // 2;

# Parent first, then sub-queues (order matters)
my @Queues = (
    { Name => 'Beschaffung',                  Comment => 'Uebergeordnete Queue fuer alle Beschaffungsvorgaenge' },
    { Name => 'Beschaffung::BANF',            Comment => 'Queue fuer neue Bestellanforderungen' },
    { Name => 'Beschaffung::Genehmigung',     Comment => 'Queue fuer Genehmigungsvorgaenge' },
    { Name => 'Beschaffung::Bestellung',      Comment => 'Queue fuer versendete Bestellungen' },
    { Name => 'Beschaffung::Wareneingang',    Comment => 'Queue fuer Wareneingangspruefung' },
    { Name => 'Beschaffung::Rechnungspruefung', Comment => 'Queue fuer Rechnungspruefung, Kontierung und Freigabe' },
);

my ($created, $skipped, $errors) = (0, 0, 0);

for my $Queue (@Queues) {
    my $ExistingID = $QueueObject->QueueLookup(Queue => $Queue->{Name});
    if ($ExistingID) {
        print "SKIP  '$Queue->{Name}' (already exists, ID=$ExistingID)\n";
        $skipped++;
        next;
    }

    my $QueueID = $QueueObject->QueueAdd(
        Name              => $Queue->{Name},
        ValidID           => 1,
        GroupID           => $UsersGroupID,
        FollowUpID        => 1,
        FollowUpLock      => 0,
        SystemAddressID   => 1,
        SalutationID      => 1,
        SignatureID       => 1,
        UnlockTimeout     => 0,
        Comment           => $Queue->{Comment},
        UserID            => 1,
    );

    if ($QueueID) {
        print "OK    '$Queue->{Name}' created (ID=$QueueID)\n";
        $created++;
    } else {
        print "ERROR '$Queue->{Name}' - QueueAdd failed\n";
        $errors++;
    }
}

# Ensure all valid agents have full access to the users group (queues live there)
print "\n=== Granting agents rw on users group ===\n";
my %AllUsers = $UserObject->UserList(Type => 'Long', Valid => 1);
my @PermTypes = qw(ro move_into create note owner priority rw);
for my $UID (sort keys %AllUsers) {
    my %Existing = $GroupObject->PermissionUserGet(UserID => $UID, Type => 'rw');
    if ($Existing{$UsersGroupID}) {
        print "SKIP  $AllUsers{$UID} (already has rw)\n";
        next;
    }
    for my $Type (@PermTypes) {
        $GroupObject->PermissionGroupUserAdd(
            GID        => $UsersGroupID,
            UID        => $UID,
            Permission => { $Type => 1 },
            UserID     => 1,
        );
    }
    print "OK    $AllUsers{$UID} -> users group rw granted\n";
}

print "\n--- Summary: $created created, $skipped skipped, $errors errors ---\n";
exit($errors ? 1 : 0);
