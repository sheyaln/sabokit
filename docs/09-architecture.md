---
layout: default
title: "Part 9: Architecture"
---

# Part 9: Architecture

System architecture and component relationships.

## 9.1 Infrastructure Overview

```
                                    INTERNET
                                        |
                           +------------+------------+
                           |            |            |
                           v            v            v
                    +------+-----+ +----+----+ +-----+------+
                    | tools-prod | | mgmt    | | authentik  |
                    | (public)   | | (public)| | (public)   |
                    +------+-----+ +----+----+ +-----+------+
                           |            |            |
                           +------------+------------+
                                        |
                              Private Network (VPC)
                              10.0.0.0/24
                                        |
                           +------------+------------+
                           |                         |
                           v                         v
                    +------+------+          +-------+-------+
                    | PostgreSQL  |          | S3 Storage    |
                    | (managed)   |          | - appdata     |
                    | 10.0.0.x    |          | - acme certs  |
                    +-------------+          | - tf state    |
                                             +---------------+
```

## 9.2 Server Roles

### tools-prod

```
+--------------------------------------------------+
| tools-prod                                        |
|                                                   |
| +-------+   +--------+   +---------+   +-------+  |
| |Traefik|-->|Decidim |   |Outline  |   |Nextcloud |
| | :80   |   | :3000  |   | :3000   |   | :80    | |
| | :443  |   +--------+   +---------+   +-------+  |
| +---+---+                                         |
|     |       +--------+   +---------+   +-------+  |
|     +------>|EspoCRM |   |Leantime |   |OnlyOff | |
|             | :80    |   | :80     |   | :8000  | |
|             +--------+   +---------+   +-------+  |
|                                                   |
| +----------+  +----------+  +----------+          |
| |NodeExport|  |cAdvisor  |  |Alloy     |          |
| | :9100    |  | :8080    |  | (logs)   |          |
| +----------+  +----------+  +----------+          |
+--------------------------------------------------+
```

### management

```
+--------------------------------------------------+
| management                                        |
|                                                   |
| +-------+   +--------+   +---------+   +-------+  |
| |Traefik|-->|Grafana |   |Zabbix   |   |Wobbler|  |
| | :80   |   | :3000  |   | :8080   |   | :5000 |  |
| | :443  |   +--------+   +---------+   +-------+  |
| +-------+                                         |
|             +----------+  +----------+            |
|             |Prometheus|  |Loki      |            |
|             | :9090    |  | :3100    |            |
|             +----------+  +----------+            |
|                                                   |
|             +----------+  +----------+            |
|             |n8n       |  |Zabbix Srv|            |
|             | :5678    |  | :10051   |            |
|             +----------+  +----------+            |
+--------------------------------------------------+
```

### authentik-prod

```
+--------------------------------------------------+
| authentik-prod                                    |
|                                                   |
| +-------+   +-------------+   +-----------+       |
| |Traefik|-->|Authentik    |   |Authentik  |       |
| | :80   |   |Server :9000 |   |Worker     |       |
| | :443  |   +-------------+   +-----------+       |
| +-------+                                         |
|             +-------------+                       |
|             |Redis        |                       |
|             | :6379       |                       |
|             +-------------+                       |
|                                                   |
| +----------+  +----------+  +----------+          |
| |NodeExport|  |cAdvisor  |  |Alloy     |          |
| | :9100    |  | :8080    |  | (logs)   |          |
| +----------+  +----------+  +----------+          |
+--------------------------------------------------+
```

## 9.3 Request Flow

### Web Request

```
User Browser
     |
     | HTTPS (443)
     v
DNS (example.org -> your-tools-prod-ip)
     |
     v
+----+----+
| Traefik |  (TLS termination, routing via Host header)
+----+----+
     |
     | HTTP (internal)
     v
+----+----+
| App     |  (Outline, Decidim, etc.)
+----+----+
     |
     | PostgreSQL
     v
+----+----+
| Database|  (Managed PostgreSQL)
+---------+
```

### Authentication Flow

```
User
  |
  | 1. Access app
  v
Application
  |
  | 2. Redirect to Authentik
  v
Authentik (gateway.example.org)
  |
  | 3. Login form
  v
User
  |
  | 4. Enter credentials / Social login
  v
Authentik
  |
  | 5. Validate, create session
  | 6. Redirect with token
  v
Application
  |
  | 7. Validate token with Authentik
  | 8. Create session
  v
User (logged in)
```

## 9.4 Monitoring Flow

### Metrics

```
+-------------+     +-------------+     +-------------+
| tools-prod  |     | authentik   |     | management  |
|             |     |             |     |             |
| NodeExporter|     | NodeExporter|     | NodeExporter|
| :9100       |     | :9100       |     | :9100       |
+------+------+     +------+------+     +------+------+
       |                   |                   |
       | scrape            | scrape            | scrape
       v                   v                   v
       +-------------------+-------------------+
                           |
                    +------+------+
                    | Prometheus  |
                    | (management)|
                    +------+------+
                           |
                           v
                    +------+------+
                    | Grafana     |
                    +-------------+
```

### Logs

```
+-------------+     +-------------+
| tools-prod  |     | authentik   |
|             |     |             |
| Alloy       |     | Alloy       |
+------+------+     +------+------+
       |                   |
       | push              | push
       | (3100)            | (3100)
       v                   v
       +-------------------+
                |
         +------+------+
         | Loki        |
         | (management)|
         +------+------+
                |
                v
         +------+------+
         | Grafana     |
         +-------------+
```

## 9.5 Secret Flow

```
+-------------------+
| Terraform         |
| (scaleway-infra)  |
| (authentik)       |
+--------+----------+
         |
         | create secrets
         v
+--------+----------+
| Scaleway          |
| Secret Manager    |
+--------+----------+
         |
         | lookup
         v
+--------+----------+
| Ansible           |
| (group_vars)      |
+--------+----------+
         |
         | template
         v
+--------+----------+
| .env file         |
| (/opt/app/.env)   |
+--------+----------+
         |
         | read
         v
+--------+----------+
| Docker Container  |
| (environment vars)|
+-------------------+
```

## 9.6 Network Topology

```
                    INTERNET
                        |
        +---------------+---------------+
        |               |               |
   (public IP)     (public IP)     (public IP)
   tools-prod      management      authentik
        |               |               |
        +---------------+---------------+
                        |
              Private Network (VPC)
              10.0.0.0/24
                        |
        +---------------+---------------+
        |               |               |
    10.0.0.3        10.0.0.5        10.0.0.2
   (tools-prod)   (management)   (authentik)
                        |
                        |
              +-------------------+
              | Managed PostgreSQL|
              | (private IP)      |
              +-------------------+
```

> Note: Replace example IPs with your actual Scaleway server IPs.

## 9.7 DNS Structure

```
example.org (production domain)
├── @ (root) -> your website
├── www -> your website
├── gateway -> authentik-prod IP (Authentik)
├── cloud -> tools-prod IP (Nextcloud)
├── wiki -> tools-prod IP (Outline)
├── voting -> tools-prod IP (Decidim)
├── espo -> tools-prod IP (EspoCRM)
├── * (wildcard) -> tools-prod IP
└── [email records for your mail provider]

example.cc (management domain)
├── grafana -> management IP
├── zabbix -> management IP
└── wobbler -> management IP
```

> Note: Replace `example.org` and `example.cc` with your actual domains.

## 9.8 Component Dependencies

```
                    +----------+
                    | Authentik|
                    +----+-----+
                         |
          +--------------+---------------+
          |              |               |
          v              v               v
     +--------+    +--------+      +--------+
     |Grafana |    |Outline |      |Decidim |
     +--------+    +--------+      +--------+
          |              |               |
          +--------------+---------------+
                         |
                         v
                  +------+------+
                  | PostgreSQL  |
                  +-------------+

If PostgreSQL down: All apps fail
If Authentik down: No logins work
If Traefik down: No web access
```
