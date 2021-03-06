#--
# Copyright (c) 2010-2012 Michael Berkovich, tr8n.net
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

####################################################################### 
# 
# Method Token Forms
#
# {user.name}  
# {user.name:gender}
# 
####################################################################### 

module Tr8n
  module Tokens
    class Method < Tr8n::Tokens::Base
      def self.expression
        /(\{[^_:.][\w]*(\.[\w]+)(:[\w]+)*(::[\w]+)*\})/
      end
    
      def object_name
        @object_name ||= short_name.split(".").first
      end
    
      def object_method_name
        @object_method_name ||= short_name.split(".").last
      end

      def substitute(translation_key, language, label, values = {}, options = {})
        object = values[object_name.to_sym]
        raise Tr8n::Tr8n::Exception.new("Missing value for a token: #{full_name}") unless object
        object_value = sanitize(object, object.send(object_method_name), options.merge(:sanitize_values => true), language)
        label.gsub(full_name, object_value)
      end
    end
  end
end