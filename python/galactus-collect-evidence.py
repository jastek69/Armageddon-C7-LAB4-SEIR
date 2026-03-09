#!/usr/bin/env python3
import json, os, subprocess, sys, argparse, datetime
from pathlib import Path

# Galactus doesn't trust dashboards. He trusts artifacts. This script turns infrastructure into evidence.
# Audits, incidents, and regulated environments require reproducible proof—automation wins promotions.
# This is a multi-cloud evidence collector that outputs regulator-ready artifacts from AWS + GCP on demand."

def run(cmd: list[str]) -> str:
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        return f"ERROR running {' '.join(cmd)}\nSTDERR:\n{p.stderr}\nSTDOUT:\n{p.stdout}"
    return p.stdout.strip()

def write_file(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content + "\n", encoding="utf-8")

def now_iso():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

# ---------- AWS TOKYO ----------
def collect_aws_tokyo(outdir: Path, profile: str|None):
    region = "ap-northeast-1"
    env = os.environ.copy()
    if profile:
        env["AWS_PROFILE"] = profile

    def aws(args):
        return run(["aws"] + args + ["--region", region])

    evidence = {"timestamp": now_iso(), "region": region, "checks": {}}

    # 1) RDS inventory (Tokyo should have it)
    evidence["checks"]["rds_instances_tokyo"] = aws(["rds", "describe-db-instances"])

    # 2) TGW inventory (prove hub exists)
    evidence["checks"]["tgw_list"] = aws(["ec2", "describe-transit-gateways"])

    # 3) VPN connections (TGW-attached) + tunnel status
    evidence["checks"]["vpn_connections"] = aws(["ec2", "describe-vpn-connections"])

    # 4) Route tables (prove SP/GCP CIDRs route to TGW)
    evidence["checks"]["route_tables"] = aws(["ec2", "describe-route-tables"])

    # 5) Security groups (prove RDS ingress is controlled)
    evidence["checks"]["security_groups"] = aws(["ec2", "describe-security-groups"])

    # 6) CloudTrail lookup (recent change trail) – optional but very useful
    # Requires permissions; if it errors, the output will show that (still evidence).
    evidence["checks"]["cloudtrail_recent"] = run(["aws","cloudtrail","lookup-events","--max-results","25","--region",region])

    write_file(outdir / "aws_evidence.json", json.dumps(evidence, indent=2))
    # Also dump human-readable text
    write_file(outdir / "aws_vpn_connections.txt", evidence["checks"]["vpn_connections"])
    write_file(outdir / "aws_routes.txt", evidence["checks"]["route_tables"])

# ---------- GCP IOWA (NY BRANCH) ----------
def collect_gcp_ny(outdir: Path, project: str, region: str):
    def gcloud(args):
        return run(["gcloud"] + args + ["--project", project])

    evidence = {"timestamp": now_iso(), "project": project, "region": region, "checks": {}}

    # 1) MIG state
    evidence["checks"]["mig_list"] = gcloud(["compute","instance-groups","managed","list","--regions",region])

    # 2) Forwarding rules (prove INTERNAL_MANAGED + private IP)
    evidence["checks"]["forwarding_rules"] = gcloud(["compute","forwarding-rules","list","--regions",region])

    # 3) Target HTTPS proxies (prove cert map attached)
    evidence["checks"]["target_https_proxies"] = gcloud(["compute","target-https-proxies","list","--regions",region])

    # 4) Backend services / health checks
    evidence["checks"]["backend_services"] = gcloud(["compute","backend-services","list","--regions",region])
    evidence["checks"]["health_checks"] = gcloud(["compute","health-checks","list"])

    # 5) Firewall rules (prove only VPN/TGW CIDRs can access 443)
    evidence["checks"]["firewall_rules"] = gcloud(["compute","firewall-rules","list"])

    # 6) VPN + BGP evidence (Cloud Router + tunnels)
    evidence["checks"]["vpn_tunnels"] = gcloud(["compute","vpn-tunnels","list","--regions",region])
    evidence["checks"]["routers"] = gcloud(["compute","routers","list","--regions",region])

    # Optional: show BGP peer status if routers are configured
    # (Students can paste router name; for now we capture the list.)
    write_file(outdir / "gcp_evidence.json", json.dumps(evidence, indent=2))

    write_file(outdir / "gcp_forwarding_rules.txt", evidence["checks"]["forwarding_rules"])
    write_file(outdir / "gcp_firewall_rules.txt", evidence["checks"]["firewall_rules"])
    write_file(outdir / "gcp_vpn_tunnels.txt", evidence["checks"]["vpn_tunnels"])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="audit-pack", help="output folder")
    ap.add_argument("--aws-profile", default=None)
    ap.add_argument("--gcp-project", default=None)
    ap.add_argument("--gcp-region", default="us-central1")
    ap.add_argument("--mode", choices=["aws-tokyo","gcp-ny","both"], default="both")
    args = ap.parse_args()

    base = Path(args.out)
    if args.mode in ("aws-tokyo","both"):
        collect_aws_tokyo(base / "tokyo", args.aws_profile)

    if args.mode in ("gcp-ny","both"):
        if not args.gcp_project:
            print("ERROR: --gcp-project is required for gcp-ny/both", file=sys.stderr)
            sys.exit(2)
        collect_gcp_ny(base / "ny", args.gcp_project, args.gcp_region)

    print(f"Evidence written to: {base.resolve()}")

if __name__ == "__main__":
    main()