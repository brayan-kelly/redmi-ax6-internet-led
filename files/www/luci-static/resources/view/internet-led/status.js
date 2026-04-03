'use strict';
'require view';
'require rpc';
'require poll';
'require ui';

var stateRpc = rpc.declare({
    object: 'internet-led-state',
    method: 'get',
});

return view.extend({
    load: function() {
        return stateRpc().then(function(res) {
            return res.state || '';
        }).catch(function(err) {
            console.error("Error reading state:", err);
            return '';
        });
    },

    render: function(initialState) {
        var self = this;
        var container = E('div', {
            style: 'max-width:600px; margin:40px auto; padding:30px; text-align:center; background:#1e1e1e; border-radius:12px;'
        });

        this.led = E('div', {
            style: 'width:60px; height:60px; border-radius:50%; background:#999; margin:20px auto; box-shadow:0 0 20px rgba(0,0,0,0.6); transition:all 0.3s ease;'
        });
        this.stateElem = E('div', {
            style: 'text-align:center; font-weight:bold; font-size:22px; margin-top:10px;'
        });

        container.appendChild(E('h2', {}, 'Internet LED Dashboard'));
        container.appendChild(this.led);
        container.appendChild(this.stateElem);

        if (!document.querySelector('#led-animations')) {
            var style = document.createElement('style');
            style.id = 'led-animations';
            style.textContent = `
                @keyframes blink {
                    0% { opacity: 1; transform: scale(1); }
                    50% { opacity: 0.5; transform: scale(0.95); }
                    100% { opacity: 1; transform: scale(1); }
                }
                @keyframes pulse {
                    0% { transform: scale(1); }
                    50% { transform: scale(1.05); }
                    100% { transform: scale(1); }
                }
            `;
            document.head.appendChild(style);
        }

        this.updateUI({ state: initialState });

        poll.add(function() {
            return stateRpc().then(function(res) {
                self.updateUI(res);
            }).catch(function(err) {
                console.error("Poll error:", err);
            });
        }, 2);

        return container;
    },

    updateUI: function(data) {
        if (!data) return;
        var state = data.state;
        var color, label, blink;
        if (state === 'ONLINE') {
            color = '#2196f3';
            label = 'ONLINE';
            blink = false;
        } else if (state === 'OFFLINE') {
            color = '#ff9800';
            label = 'OFFLINE';
            blink = true;
        } else if (state === 'DISCONNECTED' || state === 'NO CABLE') {
            color = '#666';
            label = 'NO CABLE';
            blink = false;
        } else {
            color = '#9c27b0';
            label = 'UNKNOWN';
            blink = false;
        }
        this.led.style.background = color;
        this.led.style.boxShadow = '0 0 20px ' + color;
        this.led.style.animation = blink ? 'blink 1s infinite' : 'pulse 2s infinite';
        this.stateElem.textContent = label;
        this.stateElem.style.color = color;
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
