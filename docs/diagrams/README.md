# Architecture Diagrams

## Shared Application Gateway — Azure Landing Zone

`architecture.drawio` shows a shared Application Gateway (WAF_v2) deployed in a corporate Azure landing zone following the ALZ management group hierarchy.

### What the diagram covers

| Area | Details |
|------|---------|
| **Management Group hierarchy** | Tenant Root → Platform (Connectivity) / Corp (Shared Services, Workloads A & B) |
| **Shared Services Subscription** | Application Gateway with public & private frontends, global WAF policy, NSG, User-Assigned Managed Identity |
| **Connectivity Hub** | Hub VNet with Azure Firewall (egress) and Private DNS Zones, peered to the App Gateway VNet |
| **Workload backends** | VMSS (Subscription A) and Container App (Subscription B) reached via VNet peering |
| **Key Vault** | SSL/TLS certificate store accessed by the App Gateway's managed identity |
| **Traffic flows** | Internet → Public IP → WAF → Backend Pool → Workloads; Internal → Private IP → WAF → Backend Pool → Workloads |

### How to edit

| Tool | Instructions |
|------|-------------|
| **VS Code** | Install the [Draw.io Integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) extension, then open `architecture.drawio` directly in the editor. |
| **diagrams.net** | Open [app.diagrams.net](https://app.diagrams.net), choose *Open Existing Diagram*, and select the file. |
| **Desktop app** | Download [draw.io Desktop](https://github.com/jgraph/drawio-desktop/releases) and open the file. |

> The file is standard `.drawio` XML — any tool that supports the mxGraph format can open it.
