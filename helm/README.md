# znuny

A Helm chart to deploy Znuny on Kubernetes

![Version: 0.1.6](https://img.shields.io/badge/Version-0.1.6-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 6.5.8](https://img.shields.io/badge/AppVersion-6.5.8-informational?style=flat-square)

## Values

### Znuny's configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.addons.enabled | bool | `false` | Enable application extensions.   |
| config.addons.packages | list | `[]` | Define packages with the format used by Znuny (e.g. 'MyRepository:Package').   |
| config.apache.domain | string | `nil` | Set a local domain in Apache2 configurations.   |
| config.apache.rewriteRules | object | `{"externalConfigMap":{},"rules":null}` | Set rewrite rules in Apache2 configurations.   |
| config.apache.rewriteRules.externalConfigMap | object | `{}` | Define the name of a Kubernetes configMap to set the Apache2 rewrite rules.   If externalConfigMap is defined, the key "rules" will be ignored.   |
| config.apache.rewriteRules.rules | string | `nil` | Set the rewrite rules to be included.   |
| config.api.healthstatus.apiKey | string | `nil` | Set an API key to add at the global configuration.   Ignored if "externalSecret" is defined.   |
| config.api.healthstatus.externalSecret | object | `{}` | Define the name of a Kubernetes secret to set an API key to add at the global configuration.   If "externalSecret" is defined, "apiKey" will be ignored. |
| config.authentications.backends | string | `nil` | Set the authentications backends configurations as following in a single block.   |
| config.authentications.externalSecret | object | `{}` | Define the name of a Kubernetes secret to set the application authentication backends.   If "externalSecret" is defined, the key "backends" will be ignored.   |
| config.configurationOverridesDirectory | string | `"/overrides/"` | Set the directory containing configuration overrides.   (e.g /overrides/Kernel/Language/en.pm becomes /opt/otrs/Custom/Kernel/Language/en.pm).   The directory path must end with '/''. Once the container has been initialized, all the configurations contained in this directory will be copied to the /opt/otrs/Custom directory.   |
| config.logs.path | string | `"/var/log/znuny"` | Set a path to Znuny's file logging.   The file logging is enabled only if the key "path" is set.   |
| config.mails.sendmail.enabled | bool | `true` | Enable the Sendmail module.   |
| config.mails.smtp.enabled | bool | `false` | Enable the SMTP connection.   |
| config.mails.smtp.externalSecret | object | `{}` | Define the name of a Kubernetes secret to set the SMTP server credentials.   If externalSecret is defined, keys "username" and "password" will be ignored.   |
| config.mails.smtp.host | string | `nil` | Set the host of the SMTP server.   |
| config.mails.smtp.password | string | `nil` | Set the SMTP server password to connect to.   Ignored if an externalSecret is defined.   |
| config.mails.smtp.port | int | `25` | Set the port of the SMTP server.   |
| config.mails.smtp.username | string | `nil` | Set the SMTP server username to connect to.   Ignored if an externalSecret is defined.   |
| config.secureMode | bool | `true` | Set Znuny's SysConfig secure mode.   |
| config.timezone | string | `"Etc/UTC"` | Set the container timezone.   |
| config.users.admin | object | `{"externalSecret":{},"password":null,"username":"root@localhost"}` | Setting of the administrator user.   |
| config.users.admin.externalSecret | object | `{}` | Define the name of a Kubernetes secret to set the administrator credentials.   If externalSecret is defined, keys "username" and "password" will be ignored.   |
| config.users.admin.password | string | `nil` | Set the administrator's password.   Ignored if an externalSecret is defined.   |
| config.users.admin.username | string | `"root@localhost"` | Set the administrator's username.   Ignored if an externalSecret is defined.   |

### Required configurations

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.database | object | `{"externalSecret":{},"host":null,"name":"znuny","password":null,"port":5432,"username":null}` | Set the connection of the PostgreSQL database.   |
| config.database.externalSecret | object | `{}` | Define the name of a Kubernetes secret to set the database credentials.   If externalSecret is defined, keys "username" and "password" will be ignored.   |
| config.database.host | string | `nil` | Set the host of the database.   |
| config.database.name | string | `"znuny"` | Set the name of the database.   |
| config.database.password | string | `nil` | Set the database password to connect to.   Ignored if an externalSecret is defined.   |
| config.database.port | int | `5432` | Set the port of the database.   |
| config.database.username | string | `nil` | Set the database username to connect to.   Ignored if an externalSecret is defined.   |

### Extra

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| extraConfigMaps | list | `[]` | Set extras Kubernetes configMaps.   |
| extraConfigmapMounts | list | `[]` | Set extras Kubernetes configMaps mounts.   |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config | object | `{"addons":{"enabled":false,"packages":[]},"apache":{"domain":null,"rewriteRules":{"externalConfigMap":{},"rules":null}},"api":{"healthstatus":{"apiKey":null,"externalSecret":{}}},"authentications":{"backends":null,"externalSecret":{}},"configurationOverridesDirectory":"/overrides/","database":{"externalSecret":{},"host":null,"name":"znuny","password":null,"port":5432,"username":null},"logs":{"path":"/var/log/znuny"},"mails":{"sendmail":{"enabled":true},"smtp":{"enabled":false,"externalSecret":{},"host":null,"password":null,"port":25,"username":null}},"secureMode":true,"timezone":"Etc/UTC","users":{"admin":{"externalSecret":{},"password":null,"username":"root@localhost"}}}` | Set Znuny's configurations. |
| config.addons | object | `{"enabled":false,"packages":[]}` | Set application extensions if enabled.   |
| config.apache | object | `{"domain":null,"rewriteRules":{"externalConfigMap":{},"rules":null}}` | Set Apache2 custom configurations.   |
| config.api | object | `{"healthstatus":{"apiKey":null,"externalSecret":{}}}` | Set Znuny's API.   |
| config.api.healthstatus | object | `{"apiKey":null,"externalSecret":{}}` | Set the healthstatus API.   The package healthstatus must be installed.   |
| config.authentications | object | `{"backends":null,"externalSecret":{}}` | Set the application authentication backends.   |
| config.logs | object | `{"path":"/var/log/znuny"}` | Set the application logging.   |
| config.mails | object | `{"sendmail":{"enabled":true},"smtp":{"enabled":false,"externalSecret":{},"host":null,"password":null,"port":25,"username":null}}` | Set the application e-mail notifications system.   There are two mailing type :     - sendmail: Send mail with the local sendmail module.     - smtp: Connect to an external SMTP server to send mails.   Both features can't be activated simultaneously.   The feature "sendmail" will be prioritized over "smtp" as long as its "enabled" key is set to true.   |
| config.mails.sendmail | object | `{"enabled":true}` | Setting of the local Sendmail module.   |
| config.mails.smtp | object | `{"enabled":false,"externalSecret":{},"host":null,"password":null,"port":25,"username":null}` | Setting of the SMTP connection.   |
| config.users | object | `{"admin":{"externalSecret":{},"password":null,"username":"root@localhost"}}` | Set Znuny's local users.   |
| image | object | `{"externalPullSecrets":[],"pullPolicy":"IfNotPresent","pullSecrets":[],"repository":"ghcr.io/fr-bez-aosc/znuny","tag":"6.5.8-0"}` | Set the container image specifications.   |
| image.externalPullSecrets | list | `[]` | Set an external registry pull secret if a custom image hosted on a private registry is used.   Use it only if an external pullSecret exists. Otherwise, use the pullSecrets key.   Both keys can be used simultaneously.   |
| image.pullPolicy | string | `"IfNotPresent"` | Set the image pull policy.   |
| image.pullSecrets | list | `[]` | Set a registry pull secret if a custom image hosted on a private registry is used.   Use it only if a pullSecret has to be created. Otherwise, use the externalPullSecrets key.   Both keys can be used simultaneously and the secret must be encoded in base64.   |
| image.repository | string | `"ghcr.io/fr-bez-aosc/znuny"` | Set the container image to use.   |
| image.tag | string | `"6.5.8-0"` | Set the image tag to use.   |
| ingress | object | `{"annotations":{},"domains":[],"enabled":false,"tls":{"enabled":false}}` | Set the Kubernetes ingress specifications.   |
| ingress.annotations | object | `{}` | Set annotations to add to the ingress.   |
| ingress.domains | list | `[]` | Set public domains to expose to.   |
| ingress.enabled | bool | `false` | Enable the ingress features.   |
| ingress.tls | object | `{"enabled":false}` | Set TLS configurations.   |
| ingress.tls.enabled | bool | `false` | Enable TLS support.   |
| nameOverride | string | `nil` | Set a name to override the release name to deploy to.   |
| namespaceOverride | string | `nil` | Set a name to override the namespace name to deploy to.   |
| persistentVolumeClaims | list | `[]` | Set persistant volumes.   The access mode depend to your CSI.   |
| pod | object | `{"annotations":{},"autoscaling":{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80,"targetMemoryUtilizationPercentage":75},"deploymentStrategy":"Recreate","labels":{},"replicaCount":1,"resources":{"limits":{"cpu":"2000m","memory":"4096Mi"},"requests":{"cpu":"1000m","memory":"2048Mi"}},"restartPolicy":"Always","securityContext":{}}` | Set Znuny's pod specifications.   |
| pod.annotations | object | `{}` | Set annotations to add to Znuny's pod.   |
| pod.autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80,"targetMemoryUtilizationPercentage":75}` | Set the auto scaling of Znuny.   |
| pod.autoscaling.enabled | bool | `false` | Enable the Horizontal pod scaling.   |
| pod.autoscaling.maxReplicas | int | `3` | Set the miximum of replicas.  |
| pod.autoscaling.minReplicas | int | `1` | Set the minimum of replicas.   |
| pod.autoscaling.targetCPUUtilizationPercentage | int | `80` | Set the percentage of cpu to trigger the scaling.   |
| pod.autoscaling.targetMemoryUtilizationPercentage | int | `75` | Set the percentage of memory to trigger the scaling.   |
| pod.deploymentStrategy | string | `"Recreate"` | Set the deployment strategy.   |
| pod.labels | object | `{}` | Set labels to add to Znuny's pod.   |
| pod.replicaCount | int | `1` | Set replicas count.   |
| pod.resources | object | `{"limits":{"cpu":"2000m","memory":"4096Mi"},"requests":{"cpu":"1000m","memory":"2048Mi"}}` | Set Znuny's container resources.   |
| pod.resources.limits | object | `{"cpu":"2000m","memory":"4096Mi"}` | Set Znuny's container limits.   |
| pod.resources.limits.cpu | string | `"2000m"` | Set Znuny's container cpu limits.   |
| pod.resources.limits.memory | string | `"4096Mi"` | Set Znuny's container memory limits.   |
| pod.resources.requests | object | `{"cpu":"1000m","memory":"2048Mi"}` | Set Znuny's container requests.   |
| pod.resources.requests.cpu | string | `"1000m"` | Set Znuny's container cpu requests.   |
| pod.resources.requests.memory | string | `"2048Mi"` | Set Znuny's container memory requests.   |
| pod.restartPolicy | string | `"Always"` | Set the restart policy.   |
| pod.securityContext | object | `{}` | Set Znuny's pod security contexts.   |
| service | object | `{"port":80,"type":"ClusterIP"}` | Set the Kubernetes services specifications.   |
| service.port | int | `80` | Set the service port.   |
| service.type | string | `"ClusterIP"` | Set the service type.   |
| serviceAccount | object | `{"annotations":{},"create":false,"name":"znuny"}` | Set a service account.   |
| serviceAccount.annotations | object | {} | Set annotations to add to the service account.   |
| serviceAccount.create | bool | false | Specifies whether a service account should be created.   |
| serviceAccount.name | string | "znuny" | Set he name of the service account to use.   |

