# Running the Znuny image standalone (plain Docker / docker-compose)

This describes the container built by `docker/Dockerfile`, the `zcli` tool that
drives it, and the `/overrides` config mechanism — then gives a `docker-compose.yml`
to run the same image outside Kubernetes.

## 1. The Dockerfile

Two stages:

**Stage 1 (`builder`, `ruby:alpine`)** — installs `bashly` and runs
`bashly generate --env production` against `docker/src/`. Bashly is a code
generator: it takes the command tree declared in `docker/src/bashly.yml` plus
one hand-written `*_command.sh` script per leaf command, and compiles them
into a single self-contained bash executable, `zcli`. Only that compiled
binary is copied into the final image (`COPY --from=builder /tmp/zcli /usr/bin/`)
— the `docker/src/` sources never ship.

**Stage 2 (`debian:bookworm-slim`)** — the runtime image:
- Installs Apache2 + `mod_perl2`, the full set of Perl modules Znuny needs
  (`libtemplate-perl`, `libdbd-pg-perl`, `libcrypt-jwt-perl`, `libcrypt-smime-perl`
  for SAML signing, etc.), and the PostgreSQL 16 client tools.
- `cpanm Jq Net::SAML2` — `Net::SAML2` is what backs the `Kernel::System::Auth::SAML`
  / `Kernel::System::CustomerAuth::SAML` modules used for the Keycloak SSO.
- `zcli download -r <version> -s <checksum>` fetches and extracts the official
  Znuny tarball into `/opt/znuny` (see `download_command.sh`: downloads,
  md5-checks, `tar --strip-components=1` into `/opt/znuny`).
- `zcli config locales` generates `en_US`/`de_DE` locales at build time.
- `ENTRYPOINT ["zcli", "init", "all"]` — the only thing that runs at container
  start by default.

Nothing in the image is Znuny-*configured* yet (no `Config.pm`, no DB schema,
no admin user) — all of that happens at **container boot**, driven by env vars,
so the same image is reused across dev/staging/prod just by changing env vars.

## 2. What `zcli` actually is

`zcli` is a bashly CLI (`docker/src/bashly.yml` defines the tree, version `6.5.7`).
Each leaf command (`config znuny`, `user admin`, `run apache2`, …) is one shell
script under `docker/src/*_command.sh`; bashly stitches them together with
shared helpers from `docker/src/lib/` (`znuny.sh` = `Config.pm` text generator,
`database.sh` = pg helpers, `apache.sh` = vhost generator, `logger.sh` = the
JSON log-line formatter you see in container logs, plus unused bashly
boilerplate `config.sh`/`ini.sh`/`yaml.sh`). `docker/src/initialize.sh` defines
the `DEFAULT_ZNUNY_*` fallback constants used whenever the matching env var
isn't set (e.g. `DEFAULT_ZNUNY_DATABASE_HOST=localhost`,
`DEFAULT_ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY=/overrides`).

Command groups:
- `config` — writes config artifacts (`znuny.pm`, apache vhost, cron files, DB
  schema, the `/overrides` copy, timezone, locales, addon packages).
- `user` — `system` (creates the `znuny` OS user), `admin` (creates the Znuny
  admin agent via `znuny.Console.pl Admin::User::Add`), `permissions` (runs
  `znuny.SetPermissions.pl`, which `chown -R`s the whole `/opt/znuny` tree —
  this is the operation that breaks if a read-only mount sits inside that tree).
- `check` — `modules` (Perl module sanity check), `config` (`Maint::Config::Rebuild --cleanup`,
  compiles SysConfig into `ZZZAAuto.pm`).
- `run` — foreground/background process launchers: `apache2` (`apache2ctl -D FOREGROUND`,
  keeps the container alive), `cron` (`Cron.sh start`), `daemon` (`znuny.Daemon.pl start`).
- `init all|frontend|background` — canned sequences of the above, used as the
  container's actual entrypoint payload. `init all` (`docker/src/init_all_command.sh`)
  runs, **in order**:
  ```
  config timezone → config override → user system → config znuny → config apache
  → config crons → user permissions → config database → user admin
  → check modules → check config → config modules → upgrade
  → run cron & → run daemon & → run apache2   (foreground, keeps PID 1 alive)
  ```
  `init frontend` is the same minus cron/database/admin-user/upgrade (used for
  a web-only replica); `init background` is the inverse (cron worker only, no
  Apache). Not used by this chart/compose setup — `init all` runs everything
  in one pod/container.
- `download`, `upgrade`, `job migration ...` — build-time / one-off maintenance
  commands.

Every env var `zcli` reads is declared in `bashly.yml` under
`environment_variables:` (that's also where `--help` text comes from).

## 3. The `/overrides` mount and the two config channels

**`zcli config override`** (`config_override_command.sh`), step 2 of `init all`,
runs *before* `user permissions`. It walks
`$ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY` (default `/overrides`) and mirrors
its directory tree + files into `/opt/znuny/Custom/`, preserving relative
paths, via plain `find`+`cp -f`. That's the entire mechanism — no merging,
no templating, just a recursive file copy.

`/opt/znuny/Custom` is on Znuny's `@INC` / template search path, so anything
copied there **shadows** the equivalent file under `/opt/znuny/Kernel/...` or
`/opt/znuny/var/...`:
- Perl modules, e.g. `Custom/Kernel/System/CustomerAuth/SAML.pm` overriding
  the stock one.
- Templates (`.tt` files), e.g. a customer-portal `.tt` under
  `Custom/Kernel/Output/HTML/Templates/Standard/`.

**It is *not* consulted for two things Znuny loads by a different, hardcoded
mechanism:**
- SysConfig (`Kernel::Config::Files::*` — anything under
  `Kernel/Config/Files/*.pm`, alphabetically globbed, `ZZZAAuto.pm` = compiled
  SysConfig, so a `ZZZZZ_*.pm` sorts after it and overrides it).
- Translations (`Kernel/Language/*.pm`).

Both of those are only ever read from the real `/opt/znuny/Kernel/...` path.
So there are two independent override channels:

| Want to change | Channel | Mechanism |
|---|---|---|
| UI template / Perl module | `/overrides` → `Custom/` | `zcli config override` file copy, step 2 |
| SysConfig setting / branding | a `ZZZZZ_*.pm` dropped straight into `Kernel/Config/Files/` | not `zcli`-managed — you place the file yourself before `zcli init all` (see §4) |

**The chown gotcha:** `user permissions` (step 7) runs
`znuny.SetPermissions.pl`, which recursively `chown`s all of `/opt/znuny`.
If any file *inside* that tree is a read-only bind mount (a Kubernetes
ConfigMap volume is always read-only; a Docker bind mount can be read-only
too if you mount it `:ro`), the chown on that one file fails and
`SetPermissions.pl` exits non-zero, which aborts the whole `init all` chain —
crash-looping the container. That's why the Helm chart never mounts the
branding ConfigMap directly under `Kernel/Config/Files/`; it mounts it at
`/branding/` (outside the tree) and a wrapper entrypoint `cp`s it in before
calling `zcli init all` (see `values-thws.yaml: pod.command/args`). In plain
Docker you can just bind-mount the file **read-write** directly into
`Kernel/Config/Files/` and skip the copy step entirely — Docker bind mounts
don't have Kubernetes' ConfigMap read-only restriction, so `SetPermissions.pl`
can chown it in place. That simplification is reflected in the compose file
below.

## 4. Deploying standalone with Docker / docker-compose

Directory layout on the host:

```
znuny-deploy/
├── docker-compose.yml
├── .env
├── overrides/              # -> mounted at /overrides (Custom/ tree + SAML certs)
│   └── SAML/
│       ├── idp.crt         # Keycloak (or other IdP) signing cert
│       ├── sp.crt
│       └── sp.key
└── branding/
    └── ZZZZZ_THWS.pm       # SysConfig override, see CLAUDE.md example
```

**`.env`**
```bash
DB_PASSWORD=change-me
ADMIN_PASSWORD=change-me-too
ZNUNY_APACHE_DOMAIN=ticket.example.org
```

**`docker-compose.yml`**
```yaml
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: znuny
      POSTGRES_USER: znuny
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

  znuny:
    build:
      context: ./docker      # the repo's docker/ dir (Dockerfile + src/)
    restart: unless-stopped
    depends_on:
      - postgres
    ports:
      - "8080:80"
    environment:
      ZNUNY_TIMEZONE: Europe/Berlin
      ZNUNY_SECURE_MODE: "1"
      ZNUNY_DATABASE_HOST: postgres
      ZNUNY_DATABASE_PORT: "5432"
      ZNUNY_DATABASE_NAME: znuny
      ZNUNY_DATABASE_USER: znuny
      ZNUNY_DATABASE_PASSWORD: ${DB_PASSWORD}
      ZNUNY_APACHE_DOMAIN: ${ZNUNY_APACHE_DOMAIN}
      ZNUNY_USER_ADMIN_NAME: admin
      ZNUNY_USER_ADMIN_PASSWORD: ${ADMIN_PASSWORD}
      ZNUNY_MAILING_TYPE: sendmail
      ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY: /overrides
      # Raw Perl lines appended verbatim into Config.pm's sub Load — this is
      # exactly how agent+customer SAML auth is wired in values-thws.yaml.
      ZNUNY_AUTHENTICATIONS_BACKENDS: |
        $Self->{'AuthModule1'}                                = 'Kernel::System::Auth::SAML';
        $Self->{'AuthModule::SAML::Issuer1'}                  = 'https://${ZNUNY_APACHE_DOMAIN}/';
        $Self->{'AuthModule::SAML::RequestAssertionConsumerURL1'} = 'https://${ZNUNY_APACHE_DOMAIN}/index.pl?Action=Login';
        $Self->{'AuthModule::SAML::RequestSignKey1'}          = '/overrides/SAML/sp.key';
        $Self->{'AuthModule::SAML::RequestMetaDataURL1'}      = 'https://keycloak.example.org/realms/example/protocol/saml/descriptor';
        $Self->{'AuthModule::SAML::IdPCACert1'}               = '/overrides/SAML/idp.crt';
        $Self->{'AuthSyncModule::SAML::UserSyncMap1'} = { UserFirstname => 'givenName', UserLastname => 'sn', UserEmail => 'email' };
        $Self->{'AuthSyncModule::SAML::UserSyncInitialGroups1'} = ['users'];
        $Self->{'AuthSyncModule::SAML::UserSyncGroupsDefinition::Attribute1'} = 'groups';
        $Self->{'AuthSyncModule::SAML::UserSyncGroupsDefinition1'} = {
            '/znuny-admins' => { admin => { rw => 1 }, users => { rw => 1 } },
            '/znuny-agents' => { users => { rw => 1 } },
        };
        $Self->{'Customer::AuthModule1'}                            = 'Kernel::System::CustomerAuth::SAML';
        $Self->{'Customer::AuthModule::SAML::Issuer1'}              = 'https://${ZNUNY_APACHE_DOMAIN}/';
        $Self->{'Customer::AuthModule::SAML::RequestAssertionConsumerURL1'} = 'https://${ZNUNY_APACHE_DOMAIN}/customer.pl?Action=Login';
        $Self->{'Customer::AuthModule::SAML::RequestLoginButtonText1'}      = 'Login with SSO';
        $Self->{'Customer::AuthModule::SAML::RequestSignKey1'}      = '/overrides/SAML/sp.key';
        $Self->{'Customer::AuthModule::SAML::RequestMetaDataURL1'}  = 'https://keycloak.example.org/realms/example/protocol/saml/descriptor';
        $Self->{'Customer::AuthModule::SAML::IdPCACert1'}           = '/overrides/SAML/idp.crt';
        $Self->{'Customer::AuthModule::SAML::UserSyncMap1'} = { UserFirstname => 'givenName', UserLastname => 'sn', UserEmail => 'email' };
    volumes:
      - ./overrides:/overrides
      # Bind-mount the SysConfig override straight into Kernel/Config/Files —
      # a plain (writable) bind mount, so SetPermissions.pl can chown it.
      # No wrapper entrypoint needed, unlike the Kubernetes ConfigMap case.
      - ./branding/ZZZZZ_THWS.pm:/opt/znuny/Kernel/Config/Files/ZZZZZ_THWS.pm
      - znuny-data:/opt/znuny/var
    healthcheck:
      test: ["CMD", "curl", "-fsk", "http://localhost/znuny/customer.pl"]
      interval: 15s
      timeout: 5s
      retries: 6
      start_period: 180s   # first boot runs DB schema init + package checks

volumes:
  pgdata:
  znuny-data:
```

Then:
```bash
docker compose up -d
```

First boot runs the full `init all` chain (schema creation via
`database_init_pgsql`, admin user creation, `Maint::Config::Rebuild`), which
can take 1–3 minutes — the `start_period` above accounts for that. Watch it with:
```bash
docker compose logs -f znuny
```
Each line is a JSON object (`{"timestamp":...,"source":"config_database","message":...}`)
emitted by the `customLogger` helper in `docker/src/lib/logger.sh`.

**Notes / gotchas carried over from the Kubernetes deployment:**
- The container only ever serves plain HTTP on port 80 — TLS is expected to
  be terminated by a reverse proxy in front of it (Apache/Ingress in the k8s
  case; put Caddy/Traefik/nginx in front for standalone Docker). `HttpType`/`FQDN`
  in `Config.pm` should match whatever the public URL actually is, since SAML
  assertion URLs are built from it.
- `ZNUNY_LOG_PATH` is the variable `config_znuny_command.sh` actually checks
  (see `docker/src/config_znuny_command.sh:64`). The Helm chart's ConfigMap
  template previously emitted `ZNUNY_LOGS_PATH` (with an `S`), which silently
  never matched, so `config.logs.path` in `values-thws.yaml` was a no-op and
  logging always fell back to syslog — fixed in
  `helm/templates/configmaps/znuny-global-configuration.yaml` and rolled out
  live (`helm upgrade` + `kubectl rollout restart deployment/znuny`, since
  `envFrom: configMapRef` values don't refresh on a running pod by themselves).
  Set `ZNUNY_LOG_PATH` directly in the standalone compose setup for file logging.
- Rerunning `docker compose up` against a non-empty `pgdata` volume is safe —
  `config_database_command.sh` checks `information_schema.tables` first and
  skips schema init if the DB isn't empty (`database_check_pgsql`).
- For the SAML flow to work, the SP metadata (equivalent of
  `znuny-sp-metadata.xml`) must be generated from the same `sp.crt`/`sp.key`
  pair mounted at `/overrides/SAML/` and registered with the IdP (Keycloak)
  client — same requirement as the Kubernetes setup, just no `deploy.sh`
  automation for it here; generate the self-signed pair with `openssl` and
  build the metadata XML by hand or script it similarly to `deploy.sh`.

## 5. SAML auth: two independent stacks, and how role/group mapping works

Znuny is configured with **two separate SAML integrations** against the same
Keycloak realm — agent login (`AuthModule::SAML::*` / `AuthSyncModule::SAML::*`)
and customer login (`Customer::AuthModule::SAML::*`). They use the same
`sp.key`/`sp.crt`/`idp.crt` files and the same IdP metadata URL, but are
otherwise unrelated code paths with different capabilities.

### Agent side — stock Znuny (`Kernel::System::Auth::Sync::SAML`)

Runs on **every** agent login, not just the first. Beyond the
`UserSyncMap1` name/email sync already covered in §3, it supports table-driven
group and role provisioning straight from the SAML assertion, all keyed off
`AuthSyncModule::SAML::*` SysConfig entries (implemented in
`Kernel/System/Auth/Sync/SAML.pm`, unmodified upstream code — verified live at
`/opt/znuny/Kernel/System/Auth/Sync/SAML.pm` in the running pod):

- **`UserSyncInitialGroups<N>`** — a flat array of Znuny group names granted
  **once**, only at first account creation, with `rw` permission, regardless
  of what the SAML assertion contains. It's a safety net so a first-time login
  isn't left with zero access if the group-mapping attribute below is absent
  or unrecognized.
- **`UserSyncGroupsDefinition<N>` + `UserSyncGroupsDefinition::Attribute<N>`**
  — for one **multi-valued** SAML attribute (Keycloak emits one
  `<AttributeValue>` per group a user belongs to under a single attribute
  name, e.g. `groups`). On every login, `GetAttributeValues()` pulls **all**
  values of that attribute; each value is looked up as a top-level key in the
  definition hash, and matches grant/refresh the nested
  `{ GroupName => { rw => 1 } }` (or `ro`/`create`/etc.) permissions. Values
  with no matching key are ignored — they neither grant nor revoke anything.
- **`UserSyncAttributeGroupsDefinition<N>`** — the same permission-shape, but
  for the opposite input: several **distinct single-valued** attributes each
  carrying one fact (e.g. a `Department` attribute with value `Sales`), keyed
  as `{ AttributeName => { AttributeValue => { GroupName => {...} } } }`. Not
  used here, since Keycloak's group list naturally fits the multi-valued case
  above.
- **`UserSyncRolesDefinition<N>` / `UserSyncRolesDefinition::Attribute<N>`**
  and **`UserSyncAttributeRolesDefinition<N>`** — identical mechanics to the
  two group variants, but writing to Znuny **Roles** instead of Groups.

**Current THWS config** (`values-thws.yaml`, agent auth block): sets
`UserSyncInitialGroups1 = ['users']` and
`UserSyncGroupsDefinition1` mapping Keycloak `groups` attribute values
`/znuny-admins` → `admin`+`users` (rw) and `/znuny-agents` → `users` (rw). The
role variants are present but commented out, because a DB check
(`SELECT * FROM roles` against the live Postgres) confirms **no Roles exist
yet** in this Znuny instance — only four Groups do (`users`, `admin`, `stats`,
`timeaccounting_webservice`). Create Roles first (Agents → Roles in the admin
UI, or `Admin::Role::Add` on the console) before activating the role block.

**The `/znuny-admins` and `/znuny-agents` values are placeholders** — they
must be replaced with whatever the THWS Keycloak realm's SAML "group list"
attribute mapper actually emits (check Keycloak: Client Scopes → the SAML
client's scope → Mappers → the group-membership mapper's configured attribute
name and whether it sends full group paths or just names).

### Customer side — no group/role mapping exists

The custom override (`docker/overrides/Kernel/System/CustomerAuth/SAML.pm`,
covered in §3) only auto-creates the `CustomerUser` record — it does not call
any group- or role-equivalent API. Znuny customers don't have Roles at all;
customer-side access is governed by `CustomerGroup` relations or by ACLs on
the process itself, neither of which is configured for THWS today. Every
auto-provisioned customer therefore gets identical, default-level access —
if THWS needs tiered customer permissions (e.g. by department), that logic
would have to be added to the same override module, mirroring the
`UserSyncGroupsDefinition` pattern above but calling
`Kernel::System::CustomerGroup`'s `GroupCustomerUserAdd` instead of
`Kernel::System::Group`'s `PermissionGroupUserAdd`.
