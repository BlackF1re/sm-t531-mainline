# ChipIdea USB controller and HS PHY

* Micro-USB2.0, Qualcomm ChipIdea UDC/host and HS PHY; SM5502 MUIC at I²C`0x25`.
* `config/kernel.fragment`: CONFIG_USB_CHIPIDEA_UDC/HOST,
  CONFIG_PHY_QCOM_USB_HS, ULPI_BUS, configfs ACM/ECM/RNDIS/F_FS.
  USB ACM diagnostic exchange worked; USB Ethernet/OTG storage/peripherals
  and production MTP remain unvalidated. No wired UART console is available.
* ChipIdea/PHY system-sleep ordering: patch 0141 enters PHY low-power, releases
  working controller clocks, restores PHY reference in resume_early; sleep
  clock and PHY supply stay. Do not infer full XO release from runtime status.
* USB attached has impeded deeper sleep in recorded trials. Controller/PHY,
  PMIC supply and MUIC/VBUS are separate owners; actual board5-V switch/host
  current capability is unresolved. Do not guess a VBUS regulator/GPIO.
* SMB358 current limits do not establish USB host-role/VBUS capability.
  PM8226USBIN did not measure connector5V; extcon cable state is not voltage.
* Use one ACM reader at a time. Recover/probe without automatic USB disconnect
  or kernel mode switch; device enumeration/disappearance is not proof of panic.

* **DEVICE:** full Android root ADB works with Samsung USB
  `04e8:6860`, composite `mtp, acm, adb`, CONFIGURED. Host USB/IP can retain stale enumeration across reboot; re-identify the
  tablet before attempting reconnection.
  `sys.boot_completed=1` plus mounted `/data` distinguished full Android from
  charger mode; a charging screen alone is not a reliable boot-state test.
