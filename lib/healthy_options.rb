module HealthyOptions
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

  # more than temporary, for now
  # reverse index for the FLAGS structure
  INDEX = {
    long: {},
    short: {},
  }

  # sample structure, just temporary for prototyping
  FLAGS = {
    foo: {
      long: 'foo',
      short: 'f',
      value: true,
    },
    bar: {
      long: 'bar',
      short: 'b',
      value: false,
    },
  }

  # temporary, this should happen after requiretime
  FLAGS.each { |sym, hsh|
    INDEX[:long][hsh[:long]] = sym if hsh[:long]
    INDEX[:short][hsh[:short]] = sym if hsh[:short]
  }

  def self.parse(args, opts = {})
    return [args, opts] if args.empty?
    return [args, opts] unless self.flag?(args.first)

    res, flag, value = self.check_flag(args.first)
    return [args, opts] if res == :separator
    raise("unrecognized flag: #{args.first}") if res == :no_flag
    raise("flag expected for #{res}") unless flag

    sym = INDEX[:long][flag] || INDEX[:short][flag]
    raise "unrecognized flag: #{flag}" unless sym
    args.shift

    case res
    when :flag_has_val
      raise("value expected") unless value
      opts[sym] = value
    when :flag_need_val
      value = args.shift
      raise "flag #{flag} needs a value; none provided" unless value
      raise "flag #{flag} needs a value; got #{value}" if self.flag?(value)
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

  def self.parse_smashed(arg)
    opts = {}
    # preceding dash and flag have been removed
    val = arg.dup
    loop {
      break if val.empty?
      char = val.slice!(0, 1)
      sym = INDEX[:short][char]
      raise "unknown flag smashed in: #{char} in #{arg}" unless sym
      spec = FLAGS.fetch(sym)
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

  def self.flag?(arg)
    arg[0] == '-'
  end

  def self.check_flag(arg)
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
    sym = INDEX.dig(flag_type, flag)
    return [:unknown_flag, flag] unless sym
    spec = FLAGS.fetch(sym)
    if spec[:value]
      # either we have it here, or the rest of the arg is empty
      if flag_type == :short
        # anything the arg has must be the value
        val = arg.dup
        dashflag = val.slice!(0, 2)
        raise("expected #{arg} to lead with -#{flag}") if dashflag != "-#{flag}"
        return val.empty? ? [:flag_need_val, flag] : [:flag_has_val, flag, val]
      else
        val = arg.dup
        dashes = val.slice!(0, 2)
        raise("expected #{arg} arg to lead with --") if dashes != '--'
        flagcheck = val.slice!(0, flag.length)
        if flagcheck != flag
          raise("expected #{arg} (#{flagcheck}) to match #{flag}")
        end
        if val.empty?
          return [:flag_need_val, flag]
        else
          if val[0] == '='
            val.slice!(0, 1)
            if val.empty?
              raise("a value is required after =: #{arg}")
            else
              return [:flag_has_val, flag, val]
            end
          else
            raise("#{flag} requires a value but followed by #{val}")
          end
        end
      end
    else
      if flag_type == :short
        # next char must not be equals
        val = arg.dup
        dashflag = val.slice!(0, 2)
        raise("expected #{arg} to lead with -#{flag}") if dashflag != "-#{flag}"
        if val.empty?
          return [:flag_no_val, flag]
        elsif val[0] == '='
          raise("#{flag} does not take a value: #{arg}")
        else
          return [:flag_no_val_more, flag, val]
        end
      else
        # make sure this is the end of the arg
        val = arg.dup
        dashes = val.slice!(0, 2)
        raise("expected #{arg} arg to lead with --") if dashes != '--'
        flagcheck = val.slice!(0, flag.length)
        if flagcheck != flag
          raise("expected #{arg} (#{flagcheck}) to match #{flag}")
        end
        if val.empty?
          return [:flag_no_val, flag]
        else
          raise("#{flag} does not take a value: #{arg}")
        end
      end
    end
  end
end
