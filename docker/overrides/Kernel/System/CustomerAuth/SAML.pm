# --
# Custom override: extends Kernel::System::CustomerAuth::SAML with
# auto-creation of customer users on first SAML login.
# Attribute mapping is read from:
#   Customer::AuthModule::SAML::UserSyncMap<N>
# e.g. { UserFirstname => 'givenName', UserLastname => 'sn', UserEmail => 'email' }
# --

package Kernel::System::CustomerAuth::SAML;

use strict;
use warnings;

use Kernel::System::Auth::SAML::Request;
use Kernel::System::Auth::SAML::Response;
use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::CustomerUser',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    $Self->{Count} = $Param{Count} || '';

    $Self->{Config} = {};
    my $ConfigOptionPrefix = 'Customer::AuthModule::SAML::';

    for my $ConfigKey (qw(RequestLoginButtonText RequestAssertionConsumerURL Issuer)) {
        $Self->{Config}->{$ConfigKey} = $ConfigObject->Get("$ConfigOptionPrefix$ConfigKey$Self->{Count}");
        next if defined $Self->{Config}->{$ConfigKey};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need config $ConfigOptionPrefix$ConfigKey$Param{Count}.",
        );
        return;
    }

    for my $ConfigKey (qw(RequestMetaDataURL RequestMetaDataXML)) {
        $Self->{Config}->{$ConfigKey} = $ConfigObject->Get("$ConfigOptionPrefix$ConfigKey$Self->{Count}");
    }

    if (
        ( !$Self->{Config}->{RequestMetaDataURL} && !$Self->{Config}->{RequestMetaDataXML} )
        || ( $Self->{Config}->{RequestMetaDataURL} && $Self->{Config}->{RequestMetaDataXML} )
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  =>
                "Either give config ${ConfigOptionPrefix}RequestMetaDataURL$Param{Count} OR ::RequestMetaDataXML$Param{Count}.",
        );
        return;
    }

    for my $ConfigKey (qw(RequestMetaDataURLSSLOptions RequestSignKey IdPCACert)) {
        $Self->{Config}->{$ConfigKey} = $ConfigObject->Get("$ConfigOptionPrefix$ConfigKey$Self->{Count}");
    }

    $Self->{Request} = Kernel::System::Auth::SAML::Request->new(
        Count  => $Self->{Count},
        Config => $Self->{Config},
    );

    $Self->{Response} = Kernel::System::Auth::SAML::Response->new(
        Count  => $Self->{Count},
        Config => $Self->{Config},
    );

    return $Self;
}

sub GetOption {
    my ( $Self, %Param ) = @_;

    if ( !$Param{What} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need What!",
        );
        return;
    }

    my %Option = ( PreAuth => 0 );
    return $Option{ $Param{What} };
}

sub Auth {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    return if !$Param{SAMLResponse};

    my $ResponseDecoded = $Self->{Response}->DecodeResponse(
        Response => $Param{SAMLResponse},
    );
    if ( !$ResponseDecoded ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Error decoding SAML response.',
        );
        return;
    }

    my $ResponseIsValid = $Self->{Response}->IsValid(
        ExpectedSAMLRequestID => $Param{ExpectedSAMLRequestID},
    );
    if ( !$ResponseIsValid ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'SAML response is not valid.',
        );
        return;
    }

    my $UserLogin = $Self->{Response}->GetNameID();
    return if !$UserLogin;

    # Auto-create customer user on first SAML login if not yet in local DB
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my %UserData = $CustomerUserObject->CustomerUserDataGet( User => $UserLogin );

    if ( !$UserData{UserLogin} ) {
        my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
        my $ConfigOptionPrefix = 'Customer::AuthModule::SAML::';
        my $UserSyncMap        = $ConfigObject->Get( $ConfigOptionPrefix . 'UserSyncMap' . $Self->{Count} );

        my %NewUser;
        if ( IsHashRefWithData($UserSyncMap) ) {
            KEY:
            for my $Key ( sort keys %{$UserSyncMap} ) {
                my $Attribute = $UserSyncMap->{$Key};
                next KEY if !$Attribute;
                my $Value = $Self->{Response}->GetFirstAttributeValue($Attribute);
                next KEY if !defined $Value || $Value eq '';
                $NewUser{$Key} = $Value;
            }
        }

        # Log which attributes were resolved for debugging
        $LogObject->Log(
            Priority => 'notice',
            Message  => "SAML auto-create for '$UserLogin': attrs=" . join( ', ', map { "$_=$NewUser{$_}" } sort keys %NewUser ),
        );

        # Fallback: CustomerUserAdd requires UserFirstname, UserLastname, UserEmail.
        # Derive from the NameID (which is the email address) if SAML attributes are missing.
        if ( !$NewUser{UserEmail} ) {
            $NewUser{UserEmail} = $UserLogin;
        }
        if ( !$NewUser{UserFirstname} ) {
            # e.g. "andreas.schiffler@thws.de" -> "andreas"
            ( $NewUser{UserFirstname} ) = $UserLogin =~ m{^([^.@]+)};
            $NewUser{UserFirstname} //= $UserLogin;
        }
        if ( !$NewUser{UserLastname} ) {
            # e.g. "andreas.schiffler@thws.de" -> "schiffler"
            ( $NewUser{UserLastname} ) = $UserLogin =~ m{^[^.]+\.([^@]+)@};
            $NewUser{UserLastname} //= $UserLogin;
        }

        my $NewID = $CustomerUserObject->CustomerUserAdd(
            Source         => 'CustomerUser',
            UserLogin      => $UserLogin,
            UserCustomerID => $UserLogin,
            ValidID        => 1,
            UserID         => 1,
            %NewUser,
        );

        if ( !$NewID ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Could not auto-create customer user '$UserLogin' from SAML.",
            );
            return;
        }

        $LogObject->Log(
            Priority => 'notice',
            Message  => "Auto-created customer user '$UserLogin' from SAML attributes.",
        );
    }

    return $UserLogin;
}

1;
