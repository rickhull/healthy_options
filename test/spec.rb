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
    }
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
            args, opts = HealthyOptions.parse(valid_args)
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
              HealthyOptions.parse(invalid_args)
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
               #  ['--bar-baz'],  these are unrecognized
               #  ['--bar_baz'],
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
            args, opts = HealthyOptions.parse(valid_args)
            args.must_be_instance_of(Array)
            args.must_be_empty
            opts.must_be_instance_of(Hash)
            opts.wont_be_empty
            opts[:bar].must_equal(true)
          end
        end

        invalid.each do |invalid_args|
          it "must reject #{invalid_args}" do
            proc {
              HealthyOptions.parse(invalid_args)
            }.must_raise RuntimeError
          end
        end

        special.each do |special_args|
          it "must pass on #{special_args}" do
            args, opts = HealthyOptions.parse(special_args)
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
        # VALID (for p flag)
        #   -p 5
        #   -p=5
        # SMASHED VALUE (valid)
        #   -p5
        # SMASHED FLAG (valid)
        #   -op 5
        #   -op=5
        # SMASHED FLAG & VALUE
        #   -op5
      end

      describe "smashed value options" do
        # SMASHED VALUE (valid)
        #   -p5
        # SMASHED FLAG & VALUE
        #   -op5
      end

      describe "flag options" do
        # VALID
        # -p
        # INVALID
        # -poo
      end

      describe "smashed flag options" do
        # VALID (o=flag, p=flag, q=value)
        # -op
        # -pq 5
        # -oq5
        # -opq=5
        # -opq 5
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
