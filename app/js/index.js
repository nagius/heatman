// Heatman main Javascript file
String.prototype.capitalize = function() {
    return this.charAt(0).toUpperCase() + this.slice(1);
}

$(document).ready(function(){
	init();

	$("#refresh").bind("click", function(event, ui) {
		refresh_all();
	});

	$('#sensors-box').on('collapsibleexpand', function (event, ui) {
		refresh_sensors();
	});

	$('#schedules-box').on('collapsibleexpand', function (event, ui) {
		refresh_schedules();
	});

	$('#sched-channel').on('change', function(event, ui) {
		// Update mode menu according to selected channel
		var channel = $(this).val();

		$("#sched-mode").empty();
		$("#sched-mode").append($('<option disabled hidden selected> -- Mode -- </option>'));
		for (var mode of window.channels[channel]["modes"])
		{
			$("#sched-mode").append($('<option></option>').attr("value", mode).text(mode.capitalize()));
		}
		$("#sched-mode").append($('<option></option>').attr("value", "auto").text("Auto"));
		$("#sched-mode").selectmenu("refresh");
	});


	// Submit a new scheduled override
	$("form#schedules").submit(function(event) {
		event.preventDefault();

		var channel = $('#sched-channel').val(),
			mode = $("#sched-mode").val(),
			date = $("#sched-date").val(),
			time = $("#sched-time").val();

		if(channel == null || mode == null)
		{
			alert("You need to select a channel and a mode");
			return;
		}

		if(date.length == 0 || time.length == 0)
		{
			alert("You need to select a date and a time");
			return;
		}

		// Date.parse use local timezone by default
		var data = "timestamp=" + Date.parse(date + "T" + time + ":00.000")/1000;

		// Call API to save new schedule
		$.post("/api/channel/" + channel + "/schedule/" + mode, data, function(response, status) {
			refresh_schedules();
		});
	});

	$("form.overrides :input").change(function(){
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

		// Set the update time
		$("#ts-"+channel).text(timeago(data.time));
	});
}

function refresh_channels()
{
	// Update current status
	for (var channel in window.channels)
	{
		update_status(channel);
	}
}

function refresh_sensors()
{
	// Only if the collapsible is expanded
	if($("#sensors-box").collapsible("option", "collapsed") == false)
	{
		for (var sensor in window.sensors)
		{
			// Update sensors value
			$.get("/api/sensor/" + sensor, function (data, status) {
				// Using data['name'] instead of 'sensor' because asychronous variable scope is a mess and doesn't work
				// In this scope, 'sensor' still evaluate to it's last value, not the value from the loop
				$("#sensor-"+data["name"]).text(data["value"]);
			});
		}
	}
}

function refresh_schedules()
{
	// Only if the collapsible is expanded
	if($("#schedules-box").collapsible("option", "collapsed") == false)
	{
		// Clear the current displayed list
		$("#sched-list li").slice(1).remove();

		$.get("/api/schedules", function (data, status) {
			for (var id in data)
			{
				var sched = '<li class="sched-event">' +
					'<button id="delete-' + id +'" data-sched-id='+ id +' class="ui-btn ui-icon-delete ui-btn-icon-notext ui-corner-all">Delete</button>' +
					'<span>' + data[id]['channel'].capitalize() + ": " + data[id]['mode'].capitalize() + " @ " + format_date(data[id]['time']) + '</span>' +
					'</li>';

				$("#sched-list").append(sched);
				$("#sched-list").listview("refresh");

				$("#delete-" + id).bind("click", function(event, ui) {
					// Call API to delete schedule
					$.ajax({
						url: "/api/schedule/" + $(this).data("sched-id"),
						type: 'DELETE',
						success: function() {
							refresh_schedules();
						}
					});
				});
			}
		});
	}
}

function refresh_all()
{
	refresh_channels();
	refresh_sensors();
	refresh_schedules();
}

function init()
{
	$.get("/api/channels", function (data, status) {
		// Global variable loaded once
		window.channels=data;
		refresh_channels();
	});
	$.get("/api/sensors", function (data, status) {
		// Global variable loaded once
		window.sensors=data;
		refresh_sensors();
	});
}

function format_date(timestamp)
{
	return new Date(timestamp * 1000).toLocaleString();
}

function timeago(timestamp)
{
	if(timestamp == 0)
		return "";
	
	time = Math.round(Date.now()/1000) - timestamp

	if(time < 60)
		return "Just now";
	else if (time < 3600)
		return Math.round(time/60) + " min ago";
	else if (time < 86400)
		return Math.round(time / 3600) + " hours and " + Math.round(time % 3600 / 60) + " min ago";
	else
		return Math.round(time / 86400) + " days and " + Math.round(time % 86400 / 3660) + " hours ago";

	return timestamp;
}

// vim: ts=4:sw=4:ai:noet
