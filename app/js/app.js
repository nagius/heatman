// Heatman main Javascript file

$(document).ready(function(){
	init();

	$("#refresh").bind("click", function(event, ui) {
		refresh();
	});

	$("form :input").change(function(){
		// Get parameters from the form element 
		var values   = $(this).attr('id').split('-'),
		    channel  = values[0],
			mode     = values[1];

		// Set the real mode to make API call
		if (mode == "persistent")
			mode=get_form_mode(channel);

		// Set persistent option
		var data="persistent=" + $("#"+channel+"-persistent").is(":checked");

		// Call API to update mode
		$.post("/api/channel/" + channel + "/" + mode, data, function(response, status) {
			update_status(channel);
		});
		// TODO add error hanlder
	});
}); 

function get_form_mode(channel)
{
	for (var mode of window.channels[channel]["modes"])
	{
		if ($("#"+channel+"-"+mode).is(":checked"))
		{
			return mode;
		}
	}
	return null;
}

function update_status(channel)
{
	$.get("/api/channel/" + channel, function (data, status) {
		// Set checked the current mode
		for (var mode of window.channels[channel]["modes"])
		{
			$("#"+channel+"-"+mode).prop("checked", data["mode"] == mode);
			$("#"+channel+"-"+mode).checkboxradio("refresh");
		}

		// Set checked the auto mode
		$("#"+channel+"-auto").prop("checked", !data["override"]);
		$("#"+channel+"-auto").checkboxradio("refresh");

		// Set checked the persistent mode
		$("#"+channel+"-persistent").prop("checked", data["persistent"]);
		$("#"+channel+"-persistent").flipswitch("refresh");

	});
}

function refresh()
{
		// Update current status
		for (var channel in window.channels)
		{
			update_status(channel);
		}
}

function init()
{
	$.get("/api/channels", function (data, status) {
		// Global variable loaded once
		window.channels=data;
		refresh();
	});
}

// vim: ts=4:sw=4:ai:noet
