package Kernel::Config::Files::ZZZZZ_THWS;
use strict;
use warnings;
use utf8;

sub Load {
    my ($File, $Self) = @_;

    # Browser tab / title bar application name (short)
    $Self->{ProductName} = 'THWS';

    # Company name in outgoing email X-Headers (short)
    $Self->{Organization} = 'THWS';

    # Company name shown in the customer header (h1.CompanyName) (long)
    $Self->{CustomerHeadline} = 'Technische Hochschule Würzburg-Schweinfurt';

    # Optional: customer header logo. The image must be reachable, e.g.
    # placed under skins/Customer/default/img/ or referenced by full URL.
    # $Self->{CustomerLogo} = {
    #     URL         => 'skins/Customer/default/img/logo.png',
    #     StyleHeight => '45px',
    #     StyleWidth  => '216px',
    #     StyleTop    => '9px',
    #     StyleRight  => '0px',
    # };

    # Rename the customer "Create Process Ticket" menu entry
    $Self->{'CustomerFrontend::Navigation'}->{'CustomerTicketProcess'}->{'002-ProcessManagement'} = [
        {
            'Name'        => 'Neue Bestellanforderung',
            'Description'  => 'Neue Bestellanforderung erstellen.',
            'Link'        => 'Action=CustomerTicketProcess',
            'LinkOption'  => '',
            'NavBar'      => 'Ticket',
            'Type'        => 'Menu',
            'Block'       => '',
            'AccessKey'   => 'o',
            'Prio'        => '0010',
            'Group'       => [],
            'GroupRo'     => [],
        },
    ];

    return 1;
}

1;
