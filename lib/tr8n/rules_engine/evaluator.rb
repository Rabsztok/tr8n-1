#--
# Copyright (c) 2013 Michael Berkovich, tr8nhub.com
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

module Tr8n
  module RulesEngine
    
    class Evaluator
      attr_reader :env, :vars

      def initialize
        @vars = {}
        @env = {
            # McCarthy's Elementary S-functions and Predicates
            "label" => lambda { |l, r|        @env[l] = @vars[l] = r },
            "quote" => lambda { |expr|        expr },
            "car"   => lambda { |list|        list[0] },
            "cdr"   => lambda { |list|        list.drop(1) },
            "cons"  => lambda { |e, cell|     [e] + cell },
            "eq"    => lambda { |l, r|        l == r },
            "atom"  => lambda { |expr|        [Symbol, String, Fixnum, Float].include?(expr.class) },
            "cond"  => lambda { |c, t, f|     eval(c) ? eval(t) : eval(f) },

            # Tr8n Extensions
            "="       => lambda { |l, r|      l == r },                                             # ["=", 1, 2]
            "!="      => lambda { |l, r|      l != r },                                             # ["!=", 1, 2]
            "<"       => lambda { |l, r|      l < r },                                              # ["<", 1, 2]
            ">"       => lambda { |l, r|      l > r },                                              # [">", 1, 2]
            "+"       => lambda { |l, r|      l + r },                                              # ["+", 1, 2]
            "-"       => lambda { |l, r|      l - r },                                              # ["-", 1, 2]
            "*"       => lambda { |l, r|      l * r },                                              # ["*", 1, 2]
            "%"       => lambda { |l, r|      l % r },                                              # ["%", 14, 10]
            "/"       => lambda { |l, r|      (l * 1.0) / r },                                      # ["/", 1, 2]
            "!"       => lambda { |expr|      not expr },                                           # ["!", ["true"]]
            "&&"      => lambda { |*expr|     expr.all?{|e| eval(e)}  },                            # ["&&", [], [], ...]
            "||"      => lambda { |*expr|     expr.any?{|e| eval(e)} },                             # ["||", [], [], ...]
            "if"      => lambda { |c, t, f|   eval(c) ? eval(t) : eval(f) },                        # ["if", "cond", "true", "false"]
            "let"     => lambda { |l, r|      @env[l] = @vars[l] = r },                             # ["let", "n", 5]
            "and"     => lambda { |*expr|     expr.all?{|e| eval(e)}  },                            # ["and", [], [], ...]
            "or"      => lambda { |*expr|     expr.any?{|e| eval(e)} },                             # ["or", [], [], ...]
            "not"     => lambda { |val|       not val },                                            # ["not", ["true"]]
            "mod"     => lambda { |l, r|      l % r },                                              # ["mod", "@n", 10]
            "append"  => lambda { |l, r|      r.to_s + l.to_s},                                     # ["append", "world", "hello "]
            "prepend" => lambda { |l, r|      l.to_s + r.to_s},                                     # ["prepend", "hello  ", "world"]
            "true"    => lambda { true },                                                           # ["true"]
            "false"   => lambda { false },                                                          # ["false"]
            "date"    => lambda { |date|      Date.strptime(date, '%Y-%m-%d')},                     # ["date", "2010-01-01"]
            "today"   => lambda { Time.now.to_date},                                                # ["today"]
            "time"    => lambda { |expr|      Time.strptime(expr, '%Y-%m-%d %H:%M:%S')},            # ["time", "2010-01-01 10:10:05"]
            "now"     => lambda { Time.now},                                                        # ["now"]
            "match"   => lambda { |search, subject|                                                 # ["match", /a/, "abc"]
              search = regexp_from_string(search)
              not search.match(subject).nil?
            },
            "in"      => lambda { |values, search|                                                  # ["in", "1,2,3,5..10,20..24", "@n"]
              search = search.to_s.strip
              values.split(',').each do |e|
                if e.index('..')
                  bounds = e.strip.split('..')
                  return true if (bounds.first.strip..bounds.last.strip).include?(search)
                end
                return true if e.strip == search
              end
              false
            },
            "within"  => lambda { |values, search|                                                 # ["within", "0..3", "@n"]
              bounds = values.split('..').map{|d| Integer(d)}
              (bounds.first..bounds.last).include?(search)
            },
            "replace" => lambda { |search, replace, subject|                                       # ["replace", "/^a/", "v", "abc"]
              # handle regular expression
              if /\/i$/.match(search)
                  replace = replace.gsub(/\$(\d+)/, '\\\\\1') # for compatibility with Perl notation
              end
              search = regexp_from_string(search)
              subject.gsub(search, replace)
            },
            "count"   => lambda { |list|                                                          # ["count", "@genders"]
              (list.is_a?(String) ? vars[list] : list).count
            },
            "all"     => lambda { |list, value|                                                   # ["all", "@genders", "male"]
              list = (list.is_a?(String) ? vars[list] : list)
              list.is_a?(Array) ? list.all?{|e| e == value} : false
            },
            "any"     => lambda { |list, value|                                                   # ["any", "@genders", "female"]
              list = (list.is_a?(String) ? vars[list] : list)
              list.is_a?(Array) ? list.any?{|e| e == value} : false
            },
        }
      end

      def regexp_from_string(str)
        return Regexp.new(/#{str}/) unless /^\//.match(str)

        str = str.gsub(/^\//, '')

        if /\/i$/.match(str)
          str = str.gsub(/\/i$/, '')
          return Regexp.new(/#{str}/i)
        end

        str = str.gsub(/\/$/, '')
        Regexp.new(/#{str}/)
      end

      def reset!
        @vars.each do |var|
          @env.delete(var)
        end
        @vars = {}
      end

      def apply(fn, args)
        raise "undefined symbols #{fn}" unless @env.keys.include?(fn)
        @env[fn].call(*args)
      end

      def eval(expr)
        if @env["atom"].call(expr)
          return @env[expr] if @env[expr]
          return expr
        end

        fn = expr[0]
        args = expr.drop(1)

        unless ["quote", "cdr", "cond", "if", "&&", "||", "and", "or", "true", "false", "let", "count", "all", "any"].member?(fn)
          args = args.map { |a| self.eval(a) }
        end
        apply(fn, args)
      end
    end

  end
end
