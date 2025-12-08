# IntuneCLI.ps1 – Portfolio PowerShell CLI Tool

**Purpose:**  
- Retrieve Intune-managed device information for one or more users  
- Demonstrates Microsoft Graph API integration for device management  
- Fully safe for GitHub with demo fallback data

---

## **Features**

- Accepts multiple usernames via `-UserNames`  
- Displays:  
  - Device Name  
  - Operating System  
  - Compliance status  
  - Last check-in  
- Falls back to **demo devices** if Graph authentication fails  
- CLI-style output for professional automation demonstration

---

## **Usage**

```powershell
# Real Graph environment (requires login)
.\IntuneCLI.ps1 -UserNames "j.doe@company.com","j.smith@company.com"

# Demo fallback mode (safe for GitHub)
.\IntuneCLI.ps1 -UserNames "j.doe","jj"
