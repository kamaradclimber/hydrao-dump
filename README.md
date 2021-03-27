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
