This repo contains my notes around the protocol used by HYDRAO shower head.
Sadly the only supported way to get data out of is to use the official app which transmit all data to the cloud and then provide some data through an API.
Maybe it's possible to find info by looking at the packets exchanged between the shower head and the phone.

I'm especially interested in water volume (or rate?) and temperature since those are the two values which are shown in the HYDRAO application.

# First steps

I enabled bluetooth data dump on my Android phone and then launched the HYDRAO application.
After a few registration steps, data started to flow.

By looking at the bluetooth data in wireshark we can understand a few things:
- the protocol is Bluetooth Low energy
- all packets are considered ATT protocol

I've looked at some bluetooth ATT/GATT documentation and started to annotate packets in wireshark to keep track of what I understand.

### Initial findings

Some fields are shower head id, firmware version, ... we don't really care about this.
Some fields seems more interested though because the app is constantly requesting them in loop (every second or so): 0x001a, 0x001c, 0x001e and 0x0012. The other fields are requested at one point but not continuously so they likely don't contain the metric we're interested in.

### Some help from internet wisdom

In french: https://community.jeedom.com/t/plugin-blea-hydrao/11622/36


### Understanding 0x001e field


```bash
tshark -r ./hydraodump_with_comments.pcapng -2 -R "btatt.handle == 0x001e" -V | grep Value: > dump_1e
```

```ruby
File
  .read('dump_1e').split("\n").map(&:strip) # read and clean the file
  .map { |l| l.split(': ').last } # extract just the value field
  .map do |line|
    line.chars.each_slice(2).to_a.map(&:join).reverse.join # inverse the two 32bits values
        to_i(16) # now see that as decimal for readability
  end
```

They seem to be more or less constant around value 525.

### Understanding 0x0012 field

This field seems to be monotously increasing (a counter of some sort). The counter does not seem to be reset between two distinct showers.

<details>
<summary>First dump:</summary>

```
Value: 16020000
Value: 16020000
Value: 16020000
Value: 16020000
Value: 16020000
Value: 17020100
Value: 17020100
Value: 17020100
Value: 17020100
Value: 17020100
Value: 18020200
Value: 18020200
Value: 18020200
Value: 18020200
Value: 18020200
Value: 19020300
Value: 19020300
```
</details>

<details>
<summary>Second dump (nearly starting at the same value):</summary>

```
Value: 19020000
Value: 19020000
Value: 19020000
Value: 19020000
Value: 1a020100
Value: 1a020100
Value: 1a020100
Value: 1a020100
Value: 1a020100
Value: 1b020200
Value: 1b020200
Value: 1b020200
Value: 1b020200
Value: 1b020200
Value: 1b020200
Value: 1c020300
Value: 1c020300
Value: 1c020300
Value: 1c020300
Value: 1c020300
Value: 1d020400
Value: 1d020400
Value: 1d020400
Value: 1d020400
Value: 1d020400
Value: 1e020500
Value: 1e020500
Value: 1e020500
Value: 1e020500
Value: 1e020500
Value: 1f020600
Value: 1f020600
Value: 1f020600
Value: 1f020600
Value: 1f020600
Value: 20020700
Value: 20020700
Value: 20020700
Value: 20020700
Value: 20020700
Value: 21020800
Value: 21020800
```
</details>

On the 3rd dump (`80seconds_dump`), there are 42 values over ~80s. Values seems to be constant over ~5 consecutive records. It wouldindicate a counter constant over periods of 10s. This would be consistent with a counter of volume (~6 L/s). Although that would be weird to only send liters (instead of the amount really measured).

Thanks to [https://community.jeedom.com/t/plugin-blea-hydrao/11622/36](the jeedom community) here is the real explaination for this field: 2 bytes for total volume of the last 400 showers, 2 bytes for the current shower volume.

### Scripting

With a bit of scripting we can short-circuit the long feedback loop "app on the phone" -> move the dump on computer -> analysis with wireshark.
Use the `./receiver.py` script to make a dump from a computer.
