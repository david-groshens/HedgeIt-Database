# SystematicEdge SQL-Master-Client-Database

> [!IMPORTANT]
> **CONFIDENTIAL AND PROPRIETARY**  
> **Copyright © 2026 SystematicEdge Limited. All rights reserved.**  
> This software and documentation are the confidential and proprietary information of SystematicEdge. Unauthorized copying, distribution, or use of this material via any medium is strictly prohibited.

---

## Overview
This is the repo for everything around Master Client Database such as tables, auth logic, etc. The Master Client Database has 3 tables: Corporations, Individuals, Accounts.

## Usage
Access to this repository is restricted to authorized personnel of SystematicEdge.

* **Environment:** HedgeIt Application, Azure
* **Maintainers:** David Groshens

## Connection Information
- Authentication=ActiveDirectoryIntegrated
- Driver={ODBC Driver 18 for SQL Server}


## What is needed to connect to DB
- pip install pyodbc
- Visual C++ Redistributable
- ODBC Driver 18 for SQL Server (Current Version = 2018.186.02.01)
- need .env file with the following information:
    - DB_SERVER={server_name}
    - DB_DATABASE={database_name}
    - DB_USERNAME={your_systematic_edge_user_email} (Must have access to Azure, ask IT Team)
- Need To be Logged into Windows (OS) as the same user as DB_USERNAME. (For Authentication)