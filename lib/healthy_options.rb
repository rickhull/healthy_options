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
    SPECIALS.each { |sym, val| return [sym, val] if arg == val }
    flag = nil
    flag_type = nil
    RGX.each { |ft, rgx|
      if (m = rgx.match(arg))
        flag = m['flag']
        flag_type = ft
        break
      end
    }
    unless flag_type
      # arg is not a flag
      # do a sanity check for caller's sake
      raise "arg should not be empty" if arg.nil? or arg.empty?
      return [:no_flag]
    end
    sym = @index.dig(flag_type, flag)
    return [:unknown_flag, flag] unless sym
    spec = @flags.fetch(sym)

    #
    # VALIDATION
    # ---
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
          return [:flag_no_val_more, flag, val]
        end
      else
        raise("#{flag} does not take a value: #{arg}")
      end
    end
  end

  def parse(args, opts = {})
    return [args, opts] if args.empty?
    return [args, opts] unless self.class.flag?(args.first)

    res, flag, value = self.check_flag(args.first)
    return [args, opts] if res == :separator
    raise("unrecognized flag: #{args.first}") if res == :no_flag
    raise("flag expected for #{res}") unless flag

    # TODO: we should know by now whether it's a long or short flag
    sym = @index[:long][flag] || @index[:short][flag]
    raise "unrecognized flag: #{flag}" unless sym
    args.shift

    case res
    when :flag_has_val
      raise("value expected") unless value
      opts[sym] = value
    when :flag_need_val
      value = args.shift
      raise "flag #{flag} needs a value; none provided" unless value
      raise "flag #{flag} needs a value; got #{value}" if self.class.flag?(value)
      opts[sym] = value
    when :flag_no_val
      opts[sym] = true
    when :flag_no_val_more
      opts[sym] = true
      raise("more exected for #{flag} parsed as #{res}") unless value
      # look for smashed flags
      opts = opts.merge(self.parse_smashed(value))
    else
      raise "unknown result: #{res}"
    end
    self.parse(args, opts)
  end

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
      # TODO: error handling (punctuation, -p5 -5p, etc)
      if spec[:value]
        opts[sym] = val
        break
      else
        opts[sym] = true
      end
    }
    opts
  end
end
