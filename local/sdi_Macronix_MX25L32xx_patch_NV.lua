require("muhkuh_cli_init")
require("flasher")


local function sdi_init_bus(tPlugin, aAttr)
	-- Initialize the bus.
	local fOk = flasher.sdi_chip_select(tPlugin, aAttr, 0)
	assert(fOk, "Failed to set CS to 0.")
	
	fOk = flasher.sdi_idle_bytes(tPlugin, aAttr, 8)
	assert(fOk, "Failed to send 8 idle bytes.")
end



local function sdi_read_JEDEC_ID(tPlugin, aAttr)
	local strID
	
	
	local fOk = flasher.sdi_chip_select(tPlugin, aAttr, 1)
	assert(fOk, "Failed to set CS to 1.")
	
	local strData = string.char(0x9f)
	fOk = flasher.sdi_send_data(tPlugin, aAttr, strData)
	assert(fOk, "Failed to send data.")
	
	strID = flasher.sdi_receive_data(tPlugin, aAttr, 3)
	assert(strID, "Failed to receive data.")
	
	fOk = flasher.sdi_chip_select(tPlugin, aAttr, 0)
	assert(fOk, "Failed to set CS to 0.")
	
	fOk = flasher.sdi_idle_bytes(tPlugin, aAttr, 1)
	assert(fOk, "Failed to send 1 idle bytes.")
	
	return strID
end



local function sdi_send_write_enable(tPlugin, aAttr)
	local fOk = flasher.sdi_chip_select(tPlugin, aAttr, 1)
	assert(fOk, "Failed to set CS to 1.")
	
	local strData = string.char(0x06)
	fOk = flasher.sdi_send_data(tPlugin, aAttr, strData)
	assert(fOk, "Failed to send data.")
	
	fOk = flasher.sdi_chip_select(tPlugin, aAttr, 0)
	assert(fOk, "Failed to set CS to 0.")
	
	fOk = flasher.sdi_idle_bytes(tPlugin, aAttr, 1)
	assert(fOk, "Failed to send 1 idle bytes.")
end



local function sdi_read_status_register(tPlugin, aAttr)
	local strRX
	
	
	local fOk = flasher.sdi_chip_select(tPlugin, aAttr, 1)
	assert(fOk, "Failed to set CS to 1.")
	
	local strData = string.char(0x05)
	fOk = flasher.sdi_send_data(tPlugin, aAttr, strData)
	assert(fOk, "Failed to send data.")
	
	strRX = flasher.sdi_receive_data(tPlugin, aAttr, 1)
	assert(strRX, "Failed to receive data.")
	
	fOk = flasher.sdi_chip_select(tPlugin, aAttr, 0)
	assert(fOk, "Failed to set CS to 0.")
	
	fOk = flasher.sdi_idle_bytes(tPlugin, aAttr, 1)
	assert(fOk, "Failed to send 1 idle bytes.")
	
	return string.byte(strRX)
end



local function sdi_wait_for_not_busy(tPlugin, aAttr)
	repeat
		local ulStatus = sdi_read_status_register(tPlugin, aAttr)
		ulStatus = bit.band(ulStatus, 1)
	until ulStatus==0
end



local function sdi_write_status_register(tPlugin, aAttr, ucData)
	sdi_send_write_enable(tPlugin, aAttr)
	
	local fOk = flasher.sdi_chip_select(tPlugin, aAttr, 1)
	assert(fOk, "Failed to set CS to 1.")
	
	local strData = string.char(0x01, ucData)
	fOk = flasher.sdi_send_data(tPlugin, aAttr, strData)
	assert(fOk, "Failed to send data.")
	
	fOk = flasher.sdi_chip_select(tPlugin, aAttr, 0)
	assert(fOk, "Failed to set CS to 0.")
	
	fOk = flasher.sdi_idle_bytes(tPlugin, aAttr, 1)
	assert(fOk, "Failed to send 1 idle bytes.")
	
	sdi_wait_for_not_busy(tPlugin, aAttr)
end



tPlugin = tester.getCommonPlugin()
if tPlugin==nil then
	error("No plugin selected, nothing to do!")
end

-- Download the binary.
local aAttr = flasher.download(tPlugin, "netx/", tester.progress)

local fOk

-- Use SPI Flash CS0.
ulUnit = 0
ulChipSelect = 0
ulSpeed_kHz = 1000
fOk = flasher.sdi_init(tPlugin, aAttr, ulUnit, ulChipSelect, ulSpeed_kHz)
assert(fOk, "Failed to init the SPI macro interface!")

sdi_init_bus(tPlugin, aAttr)
strID = sdi_read_JEDEC_ID(tPlugin, aAttr)

if strID~=string.char(0xc2, 0x20, 0x16) then
	error("The JEDEC ID does not match the Macronix M25L32xx.")
end

print("The JEDEC ID of the device is correct!")


ucStatus_Goal = 0x40

-- Read the status register.
ucStatus_Current = sdi_read_status_register(tPlugin, aAttr)
print(string.format("Status register: 0x%02x", ucStatus_Current))

if ucStatus_Current==ucStatus_Goal then
	print("The chip is already patched!")
else
	sdi_write_status_register(tPlugin, aAttr, ucStatus_Goal)
	
	ucData = sdi_read_status_register(tPlugin, aAttr)
	if ucData~=ucStatus_Goal then
		error("Status register not written!")
	end
end

print("")
print(" #######  ##    ## ")
print("##     ## ##   ##  ")
print("##     ## ##  ##   ")
print("##     ## #####    ")
print("##     ## ##  ##   ")
print("##     ## ##   ##  ")
print(" #######  ##    ## ")
print("")

-- disconnect the plugin
tPlugin:Disconnect()
