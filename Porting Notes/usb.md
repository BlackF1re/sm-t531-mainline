# USB, MUIC and OTG

* Micro-USB2.0, Qualcomm ChipIdea UDC/host and HS PHY; SM5502 MUIC at I²C`0x25`.
  Source accessory modes include UART/jig/LAN-hub/dock; physical support and
  concurrent power/host cases are not accepted merely from MUIC tables.
* `config/kernel.fragment`: CONFIG_USB_CHIPIDEA_UDC/HOST,
  CONFIG_PHY_QCOM_USB_HS, ULPI_BUS, configfs ACM/ECM/RNDIS/F_FS.
  USB ACM diagnostic exchange worked; USB Ethernet/OTG storage/peripherals
  and production MTP remain unvalidated. No wired UART console is available.
* ChipIdea/PHY system-sleep ordering: patch0141 enters PHY low-power, releases
  working controller clocks, restores PHY reference in resume_early; sleep
  clock and PHY supply stay. Do not infer full XO release from runtime status.
* USB attached has impeded deeper sleep in recorded trials. Controller/PHY,
  PMIC supply and MUIC/VBUS are separate owners; actual board5-V switch/host
  current capability is unresolved. Do not guess a VBUS regulator/GPIO.
* SMB358 source type/temperature and current ramp are separate from USB host
  role: see [battery-charging](battery-charging.md). USBIN ADC did not measure
  connector5V; accessory detection is not an input-voltage measurement.
* Use one ACM reader at a time. Recover/probe without automatic USB disconnect
  or kernel mode switch; device enumeration/disappearance is not proof of panic.

Sources: `config/kernel.fragment`, `patches/linux/0141*`, board MUIC entries in
[source manifest](../docs/hardware-source-manifest.json),
[device snapshot](../docs/hardware-observation-20261022.json).
