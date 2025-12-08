# UserInfoCLI – PowerShell CLI Tool

**Purpose:**  
- Retrieve user information in a CLI format  
- Demonstrates Microsoft Graph API integration and PowerShell automation skills  
- Fully safe for portfolio/GitHub: includes fallback demo data

---

## **Features**

- Accepts **one or more usernames** with the `-UserNames` parameter  
- Displays:  
  - Display Name  
  - Email  
  - Department  
  - Job Title  
- Falls back to **demo data** if Graph authentication fails  
- CLI-style output suitable for automation pipelines

---

## **Usage**

```powershell
# Real Graph environment (requires login)
.\UserInfoCLI.ps1 -UserNames "j.doe@company.com","j.smith@company.com"

# Demo fallback mode (safe for GitHub)
.\UserInfoCLI.ps1 -UserNames "j.doe","jj"
