class HealthyOptions
  RGX = {
    long: %r{
    \A       # starts with
    --       # double dash
    (?'flag' # named group
      (?:    # non-capturing group
        \w+  # word chars
        -?   # possible dash
      )*     # some number of word-word- (possibly none)
      \w+    # one last word (possibly first as well)
    )        # end flag group
    }x,      # end :long regex

    short: %r{
    \A       # starts with
    -        # single dash
    (?'flag' # named group
      \w     # word char
    )        # end flag group
    }x,      # end :short regex
  }

  SPECIALS = {
    separator: '--',
  }

  def self.index(flags)
    idx = { long: {}, short: {}, }
    flags.each { |flag, cfg|
      [:long, :short].each { |fld|
        idx[fld][cfg[fld]] = flag if cfg[fld]
      }
    }
    idx
  end

  # consider dropping this and inlining calls to it
  def self.flag?(arg)
    arg[0] == '-'
  end

  def initialize(flags = {})
    self.flags = flags
  end

  def flags=(hsh)
    @flags = {}
    hsh.each { |flag, cfg|
      raise("symbol expected for #{flag}") unless flag.is_a?(Symbol)
      my_cfg = {}
      cfg.each { |sym, val|
        raise("symbol expected for #{sym}") unless sym.is_a?(Symbol)
        my_cfg[sym] = val
      }
      @flags[flag] = my_cfg
    }
    self.reindex
    @flags
  end

  def reindex
    @index = self.class.index(@flags)
  end

  def check_flag(arg)
    # note, #parse has already confirmed self.class.flag?(arg)
    SPECIALS.each { |sym, val| return [sym, val] if arg == val }
    flag = nil
    flag_type = nil

    # check the purported flag against the regex
    RGX.each { |ft, rgx|
      if (m = rgx.match(arg))
        flag = m['flag']
        flag_type = ft
        break
      end
    }
    raise "strange flag: #{arg}" unless flag_type # arg doesn't match regex

    # look up the flag in the index
    sym = @index.dig(flag_type, flag)
    return [:unknown_flag, flag] unless sym
    spec = @flags.fetch(sym)

    #
    # perform validation based on long/short and value/no-value
    # everything below here returns or raises
    #

    val = arg.dup
    first_two = val.slice!(0, 2)

    # consume and validate the flag portion of arg (now val)
    if flag_type == :short
      raise "expected #{arg} to lead with -#{flag}" if first_two != "-#{flag}"
    elsif flag_type == :long
      raise("expected #{arg} arg to lead with --") if first_two != "--"
      flagcheck = val.slice!(0, flag.length)
      if flagcheck != flag
        raise("expected #{arg} (#{flagcheck}) to match #{flag}")
      end
    end

    if spec[:value]
      # happy, common case -- the needed value is in the next arg to follow
      return [:flag_need_val, flag] if val.empty?

      # check for equals -- consume it and take the rest as value
      if val[0] == '='
        val.slice!(0, 1)
        if val.empty?
          raise("a value is required after = (#{arg})")
        else
          return [:flag_has_val, flag, val]
        end
      end

      if flag_type == :short
        # allow smashed value; the rest of the arg must be the value
        return [:flag_has_val, flag, val]
      else
        raise("could not determine value for #{flag} in #{arg}")
      end
    else
      # no value required
      return [:flag_no_val, flag] if val.empty?

      if flag_type == :short
        # next char must not be equals
        if val[0] == '='
          raise("#{flag} does not take a value: #{arg}")
        else
          # we have a short flag that doesn't take a value
          # but there is more to parse in this arg:
          # this is a case of smashed flags like -abc
          return [:flag_no_val_more, flag, val]
        end
      else
        raise("#{flag} does not take a value: #{arg}")
      end
    end
  end

  def self.pop_value(args)
    val = args.first
    raise "args is empty" unless val
    raise "#{val} is not a value" if self.flag?(val)
    args.shift
  end

  # this is a recursive method
  # opts tends to grow while args shrinks
  def parse(args, opts = {})
    return [args, opts] if args.empty?
    return [args, opts] unless self.class.flag?(args.first)

    res, flag, value = self.check_flag(args.first)
    # puts "\n\nDEBUG: #{res} #{flag} #{value}"

    return [args, opts] if res == :separator
    raise("flag expected for #{res}") unless flag # sanity check

    # TODO: we should know by now whether it's a long or short flag
    sym = @index[:long][flag] || @index[:short][flag]
    raise "unrecognized flag: #{flag}" unless sym
    args.shift

    case res
    when :flag_has_val
      raise("value expected") unless value
      opts[sym] = value
    when :flag_need_val
      opts[sym] = self.class.pop_value(args)
    when :flag_no_val
      opts[sym] = true
    when :flag_no_val_more
      opts[sym] = true
      raise("more expected for #{flag} parsed as #{res}") unless value
      # look for smashed flags
      self.parse_smashed(value).each { |smflag, smval|
        # the last smashed flag may need a val from args
        opts[smflag] = smval || self.class.pop_value(args)
      }
    else
      raise "unknown result: #{res}"
    end
    self.parse(args, opts)
  end

  # if the arg is like -abcd
  # parse() will pick off -a, and we're left with bcd
  # pass bcd to parse_smashed()
  #
  def parse_smashed(arg)
    opts = {}
    # preceding dash and flag have been removed
    val = arg.dup
    loop {
      break if val.empty?
      char = val.slice!(0, 1)
      sym = @index[:short][char]
      raise "unknown flag smashed in: #{char} in #{arg}" unless sym

      spec = @flags.fetch(sym)
      if spec[:value]
        val.slice!(0, 1) if val[0] == '='
        if val.empty?
          opts[sym] = nil # tell parse() we need another arg; ugh, hack!
        else
          opts[sym] = val
        end
        break # a value always ends the smash
      else
        opts[sym] = true
      end
    }
    opts
  end
end
