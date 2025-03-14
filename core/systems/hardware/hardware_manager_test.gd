extends GutTest

var hardware_manager := load("res://core/systems/hardware/hardware_manager.tres") as HardwareManager


func test_properties() -> void:
	#assert_not_null(hardware_manager.cards, "should return GPU cards")
	assert_true(hardware_manager.bios != "", "should return BIOS version")
	assert_not_null(hardware_manager.cpu, "should return CPU info")
	#assert_not_null(hardware_manager.gpu, "should return GPU info")
	assert_true(hardware_manager.kernel != "", "should return kernel version")
	assert_true(hardware_manager.product_name != "", "should return product name")
	assert_true(hardware_manager.vendor_name != "", "should return vendor name")


func test_get_ports() -> void:
	var cards := hardware_manager.get_gpu_cards()
	for card in cards:
		var ports := card.get_ports()
		for port in ports:
			# Virtual ports will create a new instance each time, so skip their
			# consideration for this test
			if port.name.begins_with("Virtual"):
				continue
			gut.p(str(port))
			var port_name := "-".join([card.name, port.name])
			var other_port := card.get_port(port_name)
			assert_eq(port, other_port, "should return the same port instance")


func test_get_card_clock_value() -> void:
	var cards := hardware_manager.get_gpu_cards()
	for card in cards:
		gut.p(str(card))
		var clock_value := card.get_clock_values()
		gut.p(str(clock_value))
