CONFIG_PATH="/opt/znuny/Kernel/Config.pm"

function gen_add_licence() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
# --
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2021 Znuny GmbH, https://znuny.org/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
#  Note:
# 
#  -->> Most OTRS configuration should be done via the OTRS web interface
#       and the SysConfig. Only for some configuration, such as database
#       credentials and customer data source changes, you should edit this
#       file. For changes do customer data sources you can copy the definitions
#       from Kernel/Config/Defaults.pm and paste them in this file.
#       Config.pm will not be overwritten when updating OTRS.
# --

EOF
)
}

function gen_add_package() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
package Kernel::Config;

EOF
)
}

function gen_add_use() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
use strict;
use warnings;
use utf8;

EOF
)
}

function gen_add_sub() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
sub Load {
    my \$Self = shift;

EOF
)
}

function gen_add_database_credentials() {
  HOST=${1}
  NAME=${2}
  USER=${3}
  PASSWORD=${4}

  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    # ---------------------------------------------------- #
    # database settings                                    #
    # ---------------------------------------------------- #

    # The database host
    \$Self->{DatabaseHost} = '${HOST}';

    # The database name
    \$Self->{Database} = '${NAME}';

    # The database user
    \$Self->{DatabaseUser} = '${USER}';

    # The password of database user. You also can use bin/otrs.Console.pl Maint::Database::PasswordCrypt
    # for crypted passwords
    \$Self->{DatabasePw} = '${PASSWORD}';

EOF
)
}

function gen_add_database_mysql() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    # The database DSN for MySQL ==> more: "perldoc DBD::mysql"
    \$Self->{DatabaseDSN} = "DBI:mysql:database=\$Self->{Database};host=\$Self->{DatabaseHost};";

EOF
)
}

function gen_add_database_postgresql() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    # The database DSN for PostgreSQL ==> more: "perldoc DBD::Pg"
    # if you want to use a TCP/IP connection
    \$Self->{DatabaseDSN} = "DBI:Pg:dbname=\$Self->{Database};host=\$Self->{DatabaseHost};";

EOF
)
}

function gen_add_fs_root_dir() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    # ---------------------------------------------------- #
    # fs root directory
    # ---------------------------------------------------- #
    \$Self->{Home} = '/opt/znuny';

EOF
)
}

function gen_add_mailing_sendmail() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    \$Self->{'SendmailModule'}      = 'Kernel::System::Email::Sendmail';
    \$Self->{'SendmailModule::CMD'} = '/usr/sbin/sendmail -i -f';

EOF
)
}

function gen_add_mailing_smtp() {
  HOST=${1}
  PORT=${2}
  USER=${3}
  PASSWORD=${4}
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    \$Self->{'SendmailModule'} = 'Kernel::System::Email::MultiSendmail';
    \$Self->{'SendmailModule::Host'} = '${ZNUNY_MAILING_HOST}';
    \$Self->{'SendmailModule::Port'} = '${ZNUNY_MAILING_PORT}';
    \$Self->{'SendmailModule::AuthUser'} = '${ZNUNY_MAILING_USER}';
    \$Self->{'SendmailModule::AuthPassword'} = '${ZNUNY_MAILING_PASSWORD}';

EOF
)
}

function gen_add_authentication() {
  BLOCK="${1}"

  while IFS= read -r LINE; do
    echo "    ${LINE}" >> ${CONFIG_PATH}
  done <<< "${BLOCK}"

  echo "" >> ${CONFIG_PATH}
}


function gen_add_log_file() {
  LOGPATH=${1}
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    # --------------------------------------------------- #
    # LogModule                                           #
    # --------------------------------------------------- #
    # (log backend module)
    \$Self->{'LogModule'} = 'Kernel::System::Log::File';

    # param for LogModule Kernel::System::Log::File (required!)
    \$Self->{'LogModule::LogFile'} = '${LOGPATH}';

    # param if the date (yyyy-mm) should be added as suffix to
    # logfile [0|1]
    \$Self->{'LogModule::LogFile::Date'} = 0;

    # system log cache size for admin system log (default 32k)
    \$Self->{'LogSystemCacheSize'} = 32 * 1024;

EOF
)
}

function gen_add_log_rsyslog() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    # --------------------------------------------------- #
    # LogModule                                           #
    # --------------------------------------------------- #
    # (log backend module)
    \$Self->{LogModule} = 'Kernel::System::Log::SysLog';

    # param for LogModule Kernel::System::Log::SysLog
    \$Self->{'LogModule::SysLog::Facility'} = 'user';

    # param for LogModule Kernel::System::Log::SysLog
    # (if syslog can't work with utf-8, force the log
    # charset with this option, on other chars will be
    # replaces with ?)
    \$Self->{'LogModule::SysLog::Charset'} = 'utf-8';

    # system log cache size for admin system log (default 32k)
    \$Self->{'LogSystemCacheSize'} = 32 * 1024;

EOF
)
}

function gen_add_timezone() {
  TZ=${1}
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    \$Self->{'OTRSTimeZone'} = '${TZ}';
    \$Self->{'UserDefaultTimeZone'} =  '${TZ}';

EOF
)
}

function gen_add_securemode() {
  MODE=${1}
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    \$Self->{SecureMode} = ${MODE};

EOF
)
}

function gen_add_healthstatus_apikey() {
  API_KEY=${1}
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    \$Self->{'Znuny::HealthStatus::API::Key'} =  '${API_KEY}';
EOF
)
}

function gen_add_return() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
    return 1;
}

EOF
)
}

function gen_add_system_stuff() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}
# # ---------------------------------------------------- #
# # needed system stuff (don't edit this)                #
# # ---------------------------------------------------- #
use Kernel::Config::Defaults; # import Translatable()
use parent qw(Kernel::Config::Defaults);

EOF
)
}

function gen_add_end() {
  CONTENT=$(cat << EOF | tee -a ${CONFIG_PATH}

# -----------------------------------------------------#

1;

EOF
)
}

# #
# #    $ENV{ORACLE_HOME}     = '/path/to/your/oracle';
# #    $ENV{NLS_DATE_FORMAT} = 'YYYY-MM-DD HH24:MI:SS';
# #    $ENV{NLS_LANG}        = 'AMERICAN_AMERICA.AL32UTF8';
#     # ---------------------------------------------------- #
#     # insert your own config settings "here"               #
#     # config settings taken from Kernel/Config/Defaults.pm #
#     # ---------------------------------------------------- #
#     # $Self->{SessionUseCookie} = 0;
#     # $Self->{CheckMXRecord} = 0;
#
#     # ---------------------------------------------------- #
#     # data inserted by installer                           #
#     # ---------------------------------------------------- #
#     # $DIBI$


