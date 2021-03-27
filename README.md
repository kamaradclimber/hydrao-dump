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
