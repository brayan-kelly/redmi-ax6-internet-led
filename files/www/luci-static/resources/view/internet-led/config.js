'use strict';
'require form';
'require uci';
'require view';
'require rpc';

var networkDevices = rpc.declare({
    object: 'luci-rpc',
    method: 'getNetworkDevices'
});

var ledList = rpc.declare({
    object: 'internet-led-lists',
    method: 'get_leds'
});

return view.extend({
    load: function() {
        var self = this;
        return Promise.all([
            uci.load('internet-led'),
            networkDevices(),
            ledList()
        ]).then(function(results) {
            if (results[1] && results[1].devices) {
                self.interfaces = results[1].devices;
            } else {
                self.interfaces = [];
            }
            if (results[2] && results[2].leds) {
                self.leds = results[2].leds;
            } else {
                self.leds = [];
            }
        }).catch(function(err) {
            console.error("Failed to load config or lists:", err);
            self.interfaces = [];
            self.leds = [];
        });
    },

    render: function() {
        var m, s, o;

        m = new form.Map('internet-led', _('Internet LED Indicator'),
            _('Configure the LED behavior based on internet connectivity.'));

        s = m.section(form.NamedSection, 'main', 'internet_led', _('General Settings'));
        s.anonymous = false;
        s.addremove = false;

        o = s.option(form.Flag, 'enabled', _('Enable'));
        o.rmempty = false;
        o.default = '1';

        o = s.option(form.ListValue, 'wan_if', _('WAN Interface'));
        o.rmempty = false;
        o.default = 'wan';
        o.description = _('Logical network interface name (e.g., "wan").');
        for (var i = 0; i < this.interfaces.length; i++) {
            o.value(this.interfaces[i], this.interfaces[i]);
        }
        var currentWan = uci.get('internet-led', 'main', 'wan_if');
        if (currentWan && this.interfaces.indexOf(currentWan) === -1) {
            o.value(currentWan, currentWan + ' (custom)');
        }

        o = s.option(form.Value, 'interval', _('Check Interval (seconds)'));
        o.datatype = 'uinteger';
        o.rmempty = false;
        o.default = '5';

        o = s.option(form.Value, 'fail_threshold', _('Failure Threshold'));
        o.datatype = 'uinteger';
        o.rmempty = false;
        o.default = '3';
        o.description = _('Number of consecutive failures before declaring Internet DOWN.');

        o = s.option(form.ListValue, 'blue_led', _('Blue LED'));
        o.rmempty = false;
        o.default = 'blue:network';
        o.description = _('LED name for online status (brightness 255).');
        for (var j = 0; j < this.leds.length; j++) {
            o.value(this.leds[j], this.leds[j]);
        }
        var currentBlue = uci.get('internet-led', 'main', 'blue_led');
        if (currentBlue && this.leds.indexOf(currentBlue) === -1) {
            o.value(currentBlue, currentBlue + ' (custom)');
        }

        o = s.option(form.ListValue, 'yellow_led', _('Yellow LED'));
        o.rmempty = false;
        o.default = 'yellow:network';
        o.description = _('LED name for offline status (brightness 255).');
        for (var k = 0; k < this.leds.length; k++) {
            o.value(this.leds[k], this.leds[k]);
        }
        var currentYellow = uci.get('internet-led', 'main', 'yellow_led');
        if (currentYellow && this.leds.indexOf(currentYellow) === -1) {
            o.value(currentYellow, currentYellow + ' (custom)');
        }

        o = s.option(form.Value, 'diagnostic_targets', _('Diagnostic Targets'));
        o.rmempty = false;
        o.default = '8.8.8.8 1.1.1.1 9.9.9.9';
        o.description = _('Space-separated list of IPs/hosts to ping for connectivity check.');

        return m.render();
    }
});
