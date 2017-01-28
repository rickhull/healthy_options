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
}x,          # end :long regex
  short: %r{
    \A       # starts with
    -        # single dash
    (?'flag' # named group
      \w     # word char
    )        # end flag group
}x,           # end :short regex
}

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

INDEX = {
  long: {},
  short: {},
}
FLAGS.each { |sym, hsh|
  INDEX[:long][hsh[:long]] = sym if hsh[:long]
  INDEX[:short][hsh[:short]] = sym if hsh[:short]
}

def option_parse(opts, args)
  res = check_flag(args.first)
  return [opts, args] if res.first == :no_flag

  flag = res[1] || raise("flag expected")
  sym = INDEX[:long][flag] || INDEX[:short][flag]
  raise "unrecognized flag: #{flag}" unless sym
  args.shift

  case res.first
  when :flag_has_val
    val = res[2] || raise("value expected")
    opts[sym] = val
  when :flag_need_val
    value = args.shift
    raise "flag #{flag} needs a value; got #{value}" if value[0] == '-'
    opts[sym] = value
  when :flag_no_val
    opts[sym] = true
  when :flag_no_val_more
    opts[sym] = true
    more = res[2] || raise("more expected")
    # look for smashed flags
    opts = opts.merge(parse_smashed(more))
  else
    raise "unknown result: #{res.first}"
  end
  option_parse(opts, args)
end

def parse_smashed(arg)
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

def check_value(arg)
  if arg[0] == '-'
    return :flag
  else
    return :no_flag
  end
end

def check_flag(arg)
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
    return :no_flag
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
