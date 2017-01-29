require 'minitest/autorun'
require 'healthy_options'

describe HealthyOptions do
  before do
    @flags = {
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
      barbaz1: {
        long: 'bar-baz',
        short: 'a',
        value: false,
      },
      barbaz2: {
        long: 'bar_baz',
        short: 'c',
        value: false,
      },
    }
    @options = HealthyOptions.new(@flags)
  end

  describe "parse_args" do
    describe "long options" do
      describe "value options" do
        # VALID
        #   --foo bar
        #   --foo=bar
        valid = [['--foo', 'bar'],
                 ['--foo=bar']]
        # INVALID
        #   --foo= bar (consider new feature)
        #   --foo -bar
        #   --foo <EOF>
        invalid = [['--foo=', 'bar'],
                   ['--foo', '-bar'],
                   ['--foo'],
                  ]

        valid.each do |valid_args|
          it "must parse #{valid_args}" do
            args, opts = @options.parse(valid_args)
            args.must_be_instance_of(Array)
            args.must_be_empty
            opts.must_be_instance_of(Hash)
            opts.wont_be_empty
            opts[:foo].must_equal("bar")
          end
        end

        invalid.each do |invalid_args|
          it "must reject #{invalid_args}" do
            proc {
              @options.parse(invalid_args)
            }.must_raise RuntimeError
          end
        end
      end

      describe "flag options" do
        # VALID
        #   --bar
        #   --bar-baz
        #   --bar_baz
        valid = [['--bar'],
                 ['--bar-baz'],
                 ['--bar_baz'],
                ]

        # INVALID
        #   --bar=
        #   -bar    (could be `-b ar`, or `-b -ar`, or `-b -a -r`)
        #   --.bar
        #   ---bar
        invalid = [['--bar='],
                   ['-bar'],
                   ['--.bar'],
                   ['---bar'],
                  ]

        # SPECIAL
        #   --    not a recognized flag as such; not sure how to handle yet
        special = [['--'],
                  ]

        valid.each do |valid_args|
          it "must parse #{valid_args}" do
            args, opts = @options.parse(valid_args)
            args.must_be_instance_of(Array)
            args.must_be_empty
            opts.must_be_instance_of(Hash)
            opts.wont_be_empty
            opts.keys.length == 1
            opts.values.length == 1
            opts.values.first == true
          end
        end

        invalid.each do |invalid_args|
          it "must reject #{invalid_args}" do
            proc {
              @options.parse(invalid_args)
            }.must_raise RuntimeError
          end
        end

        special.each do |special_args|
          it "must pass on #{special_args}" do
            args, opts = @options.parse(special_args)
            args.must_be_instance_of(Array)
            args.must_equal(special_args)
            opts.must_be_instance_of(Hash)
            opts.must_be_empty
          end
        end
      end
    end

    describe "short options" do
      describe "value options" do
        # VALID
        #   -f 5
        #   -f=5
        # SMASHED VALUE (valid)
        #   -f5
        # SMASHED FLAG (valid)
        #   -af 5
        #   -af=5
        # SMASHED FLAG & VALUE
        #   -af5
        arguments = {
          normal:
            [['-f', '5'],
             ['-f=5']],
          smashed_value:
            [['-f5']],
          smashed_flag:
            [['-af', '5'],
             ['-af=5']],
          smashed_flag_value:
            [['-af5']],
        }

        [:normal, :smashed_value].each do |arg_type|
          arguments.fetch(arg_type).each do |valid_args|
            it "must parse #{arg_type} args: #{valid_args}" do
              args, opts = @options.parse(valid_args)
              args.must_be_instance_of(Array)
              args.must_be_empty
              opts.must_be_instance_of(Hash)
              opts.wont_be_empty
              opts[:foo].must_equal("5")
            end
          end
        end

        [:smashed_flag, :smashed_flag_value].each do |arg_type|
          arguments.fetch(arg_type).each do |valid_args|
            it "must parse #{arg_type} args: #{valid_args}" do
              args, opts = @options.parse(valid_args)
              args.must_be_instance_of(Array)
              args.must_be_empty
              opts.must_be_instance_of(Hash)
              opts.wont_be_empty
              opts[:foo].must_equal("5")
              opts[:barbaz1].must_equal(true)
            end
          end
        end
      end

      describe "flag options" do
        # VALID
        # -b
        # SMASHED FLAG (o=flag, p=flag, q=value)
        # -ab
        # -bf 5
        # -af5
        # -abf=5
        # -abf 5
        # INVALID
        # -bar      # so long as 'r' is not a non-value flag
        arguments = {
          normal:
            [['-b']],
          smashed_flag:
            [['-ab'],
             ['-bf', '5'],
             ['-bf5'],
             ['-abf=5'],
             ['-abf', '5']],
          invalid:
            [['-bar']],
        }

        [:normal, :smashed_flag].each do |arg_type|
          arguments.fetch(arg_type).each do |valid_args|
            it "must parse #{arg_type} args: #{valid_args}" do
              args, opts = @options.parse(valid_args)
              args.must_be_instance_of(Array)
              args.must_be_empty
              opts.must_be_instance_of(Hash)
              opts.wont_be_empty
              opts[:bar].must_equal(true)
            end
          end
        end



        [:invalid].each do |arg_type|
          arguments.fetch(arg_type).each do |invalid_args|
            it "must reject #{invalid_args}" do
              proc {
                @options.parse(invalid_args)
              }.must_raise RuntimeError
            end
          end
        end
      end
    end

    describe "mixed long and short options" do
      describe "independent namespaces" do
        # tempf:  --f     -F
        # food:   --food  -f
        # expect: No collision
      end
    end
  end
end
