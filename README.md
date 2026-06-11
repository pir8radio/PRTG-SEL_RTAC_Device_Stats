***

# PRTG RTAC Connection Monitor (PowerShell)

This PowerShell script queries a device API for active connection data and formats the results for use with **PRTG Network Monitor** custom sensors. It also maintains historical logs to calculate **7-day and 30-day uptime percentages** per connection.

***

## Features

* ✅ Connects to REST API using Basic Authentication
* ✅ Ignores SSL certificate validation (for self-signed devices)
* ✅ Outputs properly formatted **PRTG JSON**
* ✅ Tracks per-connection:
  * Status (Online / Offline / Disabled)
  * Message counts (Failures, Successes)
  * Traffic totals (Sent / Received)
* ✅ Calculates:
  * 7-Day uptime %
  * 30-Day uptime %
* ✅ Maintains rolling history (auto-cleans >30 days)

***

## Requirements

* PowerShell 5.1 or newer
* PRTG custom EXE/Script Advanced sensor
* Network access to target API endpoint

***

## Parameters

| Parameter  | Description                         |
| ---------- | ----------------------------------- |
| `DeviceIP` | IP or hostname of the target device |
| `Username` | API username                        |
| `Password` | API password                        |

***

## API Endpoint Used

```
https://<DeviceIP>/api/v1/projects/active/connections
```

***

## How It Works

### 1. Authentication

* Combines username and password
* Encodes in Base64
* Sends via HTTP Basic Auth header

### 2. SSL Handling

* Overrides certificate validation to allow self-signed certs

### 3. Connection Data

* Retrieves all active connections from API
* Maps statuses:
  * `Online → 2`
  * `Offline → 1`
  * `Disabled → 0`

### 4. Logging & History

* Creates folder:
  ```
  FDC_HISTORY
  ```
* Stores per-connection logs:
  ```
  <ConnectionName>.txt
  ```

Each entry:

```
YYYY-MM-DD HH:mm:ss,<status>
```

### 5. Uptime Calculation

For each connection:

* Filters log entries by:
  * Last **7 days**
  * Last **30 days**
* Calculates uptime:
  ```
  uptime = (non-offline entries / total entries) * 100
  ```

### 6. Cleanup

* Automatically removes entries older than 30 days

***

## PRTG Channels Created

### 🔹 Global Channel

* **API Status**
  * `1` = Connections found
  * `0` = No connections

***

### 🔹 Per Connection

Each connection generates:

* `<Name> Status`
* `<Name> Failures`
* `<Name> Successes`
* `<Name> Sent`
* `<Name> Received`
* `<Name> 7-Day Uptime`
* `<Name> 30-Day Uptime`

***

## Alerts & Limits

### Uptime Thresholds

* ⚠️ Warning: `< 98%`
* ❌ Error: `< 95%`

### API Status

* ❌ Error if no connections detected

***

## Example Output

```json
{
  "prtg": {
    "result": [
      { "channel": "API Status", "value": 1 },
      { "channel": "Conn1 Status", "value": 2 },
      { "channel": "Conn1 7-Day Uptime", "value": 99 },
      { "channel": "Conn1 30-Day Uptime", "value": 97 }
    ]
  }
}
```

***

## Installation (PRTG)

1. Save script to:
   ```
   C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\
   ```

2. In PRTG:
   * Add **EXE/Script Advanced Sensor**
   * Select this script

3. Configure parameters:
   ```
   <DeviceIP> <Username> <Password>
   ```

***

## Notes & Considerations

* 🔐 **Security Warning**:
  * Script bypasses SSL validation
  * Use only in trusted environments

* 📁 Log files grow over time but are pruned automatically

* 🕒 Accuracy depends on sensor scan interval

***

## Customization Ideas

* Add email alerts for specific connection failures
* Export metrics to external monitoring systems
* Extend uptime tracking beyond 30 days
* Add retry logic for API failures

***

## License

MIT License (or customize as needed)

***


