# Project Learnings

A running log of things I learned while building this project (AWS + Terraform + Jenkins). Add each new learning as its own numbered section at the end, and add it to the index.

## Index

1. [Why 3 Elastic IPs show up in the VPC Elastic IPs page](#1-why-3-elastic-ips-show-up-in-the-vpc-elastic-ips-page)
2. [Path-based routing with `aws_lb_listener_rule`](#2-path-based-routing-with-aws_lb_listener_rule)
3. [Grafana redirecting to my app behind the ALB (`/grafana` sub-path)](#3-grafana-redirecting-to-my-app-behind-the-alb-grafana-sub-path)

---

## 1. Why 3 Elastic IPs show up in the VPC Elastic IPs page

**Short answer:** only 1 EIP is mine (NAT gateway). The other 2 are AWS-managed IPs for the 2 ALB nodes.

#### Breakdown

| # | EIP | Created by | Manageable? |
|---|-----|-----------|-------------|
| 1 | NAT gateway | My `aws_eip.eip` resource | Yes (Terraform) |
| 2 | ALB node in `ap-south-1a` (subnet1) | AWS, because of `aws_lb.myalb` | No (service managed) |
| 3 | ALB node in `ap-south-1b` (subnet2) | AWS, because of `aws_lb.myalb` | No (service managed) |

#### Why the ALB creates them

```hcl
resource "aws_lb" "myalb" {
  internal = false                                      # internet-facing
  subnets  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}
```

- An internet-facing ALB places one **load balancer node per subnet/AZ** listed.
- Each node needs its own public IP so the internet can reach it.
- 2 subnets = 2 nodes = 2 public IPs.
- AWS marks them as **Service managed** (type: `alb`) on the Elastic IPs page.

#### Things to remember

- I did **not** create these with `aws_eip`, and the `./modules/ec2_instance` module has no EIP either. Nothing is leaked.
- They cannot be released or edited manually. They are removed automatically on `terraform destroy` (or when the ALB is deleted).
- ALB needs a minimum of **2 subnets in different AZs**, so 2 ALB IPs is the minimum.
- Adding a third AZ/subnet to the ALB would add a third ALB IP.
- ALB IPs can change over time. Never hardcode them. Use the `loadbalancerdns` output (DNS name).
- They are **billed**: every public IPv4 address costs about $0.005/hour (~$3.60/month) each, plus the ALB and NAT gateway charges.

#### Common mistakes to avoid

- Assuming extra EIPs are leftovers from a previous apply. Check the **Type / Service managed** column first.
- Thinking auto-assigned public IPs (from `map_public_ip_on_launch = true`) show on the Elastic IPs page. They don't; they only appear on the instance.
- Trying to release service-managed EIPs. It isn't possible.

#### Useful commands

```bash
# List real EIPs and what they're attached to
aws ec2 describe-addresses --region ap-south-1 \
  --query "Addresses[*].[PublicIp,AllocationId,AssociationId,InstanceId,NetworkInterfaceId]" \
  --output table

# See which EIP Terraform manages
terraform state list | grep eip
terraform state show aws_eip.eip
```

---

## 2. Path-based routing with `aws_lb_listener_rule`

**Short answer:** `aws_lb_listener_rule` lets one existing ALB listener send traffic to different target groups based on the URL path, so I can serve multiple apps through a single ALB.

#### How it is used in this project

```hcl
resource "aws_lb_listener_rule" "grafanalistenerrule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myalbtggrafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }
}
```

#### What each part does

| Part | Meaning |
|------|---------|
| `listener_arn` | The existing listener (port 80) this rule is attached to |
| `priority` | Rules are checked in order, lowest number first. Must be unique per listener |
| `action` | What to do when the rule matches. Here, forward to the Grafana target group |
| `condition` / `path_pattern` | When to match. Here, URL path is `/grafana` or anything under `/grafana/` |

#### How traffic flows

| Request | Matches rule? | Goes to |
|---------|---------------|---------|
| `http://<alb-dns>/` | No, so the listener's **default action** | Flask app target group (port 5000) |
| `http://<alb-dns>/grafana` | Yes | Grafana target group (port 3000) |
| `http://<alb-dns>/grafana/login` | Yes (matches `/grafana/*`) | Grafana target group (port 3000) |

#### Things to remember

- This is why Grafana can sit in a **private subnet** and still be reachable. The ALB is the only public entry point.
- I need both `"/grafana"` and `"/grafana/*"`. The first matches the bare path, the second matches everything under it.
- Every rule needs a unique `priority`. If nothing matches any rule, the listener's `default_action` is used.
- The target group (`myalbtggrafana`) needs its own health check (`/api/health` for Grafana) and a `aws_lb_target_group_attachment` to register the instance.
- The ALB security group must be allowed to reach the target on its port (3000 for Grafana), via the monitoring instance's security group.
- Grafana must be configured to serve from the `/grafana` sub-path (`root_url` and `serve_from_sub_path = true` in `grafana.ini`), otherwise its links and assets break behind this rule.
- Besides `path_pattern`, rules can also match on `host_header`, `http_header`, `query_string`, and `source_ip`.

---

## 3. Grafana redirecting to my app behind the ALB (`/grafana` sub-path)

**Short answer:** Grafana must be told it lives under `/grafana`. Without that, it redirects to `/login`, which does not match the ALB rule, so the ALB sends the request to the Flask app (which also has a `/login` route).

#### Symptom

Opening `http://<alb-dns>/grafana` showed my Flask login page instead of Grafana.

#### Root cause

1. `/grafana` matched the listener rule and reached Grafana (so the ALB rule was fine).
2. Grafana replied with `Location: /login?redirectTo=%2Fgrafana` (no `/grafana` prefix).
3. The browser requested `/login`, which does not match `/grafana` or `/grafana/*`.
4. The ALB used the default action and sent it to the Flask app, which has its own `/login`, so it looked like the rule was broken.

#### How to read the redirect header

```
Location: /login?redirectTo=%2Fgrafana
```

| Part | Meaning |
|------|---------|
| `Location:` | Where the server tells the browser to go next (used with a `302`) |
| `/login` | The page Grafana wants, because I am not logged in |
| `redirectTo=%2Fgrafana` | Where to return after login (`%2F` is `/`) |

The `redirectTo` part is fine. The problem was `/login` missing the `/grafana` prefix. The correct response is `Location: /grafana/login?redirectTo=%2Fgrafana`.

#### Fix

In `/etc/grafana/grafana.ini` on the monitoring instance, under the `[server]` section, these lines must be present and **not commented out** (no leading `;`):

```ini
[server]
root_url = %(protocol)s://%(domain)s/grafana/
serve_from_sub_path = true
```

Then restart:

```bash
sudo systemctl restart grafana-server
```

Or apply it with `sed` (also usable in `prometheusgrafana.sh`):

```bash
sudo sed -i 's|^;\?root_url *=.*|root_url = %(protocol)s://%(domain)s/grafana/|' /etc/grafana/grafana.ini
sudo sed -i 's|^;\?serve_from_sub_path *=.*|serve_from_sub_path = true|' /etc/grafana/grafana.ini
sudo systemctl restart grafana-server
```

#### How to verify

Test on the instance first, so the ALB is out of the picture:

```bash
curl -sI http://localhost:3000/grafana | grep -i location
```

Expected: `Location: /grafana/login?redirectTo=%2Fgrafana`

Then test through the ALB:

```bash
curl -I http://<alb-dns>/grafana
```

#### Things to remember

- In `grafana.ini`, a leading `;` means the line is commented out and ignored. The default file has these settings commented out.
- The settings only work under the `[server]` section.
- Check how Grafana runs: `systemctl status grafana-server` showing `--packaging=deb` and `--config=/etc/grafana/grafana.ini` means a package install that reads that file. With Docker, `grafana.ini` on the host is ignored, so use `GF_SERVER_ROOT_URL` and `GF_SERVER_SERVE_FROM_SUB_PATH=true` env vars and recreate the container.
- User data (`prometheusgrafana.sh`) only runs at first boot. Editing the script does not change an existing instance. Fix it by hand, or force a rebuild with `terraform apply -replace=...`.
- Once the sub-path is active, the health check moves from `/api/health` to `/grafana/api/health`. Update the target group's health check path in Terraform, or the target shows unhealthy and the ALB returns 503.
- A redirect that drops the path prefix is a classic sign that an app behind a path-based ALB rule does not know its own base path. The same applies to other apps (Jenkins, Prometheus, etc.).
- When two apps share one ALB, overlapping routes like `/login` can make a routing bug look like it is pointing at the wrong app. `curl -I` and reading the `Location` header shows what is really happening.
- The Flask target group's health check should use the app's `/health` endpoint, not `/`, because `/` returns a 302 redirect to `/login` and the ALB only accepts 200 by default.
