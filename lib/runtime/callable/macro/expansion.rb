module Heist
  class Runtime
    class Macro
      
      class Expansion
        attr_reader :expression
        
        def initialize(lexical_scope, calling_scope, template, matches)
          @lexical_scope = lexical_scope
          @calling_scope = calling_scope
          @hygienic      = lexical_scope.runtime.hygienic?
          @expression    = expand(template, matches)
        end
        
      private
        
        # When a macro use is transcribed according to the template of the
        # matching <syntax rule>, pattern variables that occur in the template
        # are replaced by the subforms they match in the input. Pattern variables
        # that occur in subpatterns followed by one or more instances of the
        # identifier '...' are allowed only in subtemplates that are followed
        # by as many instances of '...'. They are replaced in the output by all
        # of the subforms they match in the input, distributed as indicated. It
        # is an error if the output cannot be built up as specified.
        # 
        # Identifiers that appear in the template but are not pattern variables
        # or the identifier '...' are inserted into the output as literal
        # identifiers. If a literal identifier is inserted as a free identifier
        # then it refers to the binding of that identifier within whose scope
        # the instance of 'syntax-rules' appears. If a literal identifier is
        # inserted as a bound identifier then it is in effect renamed to prevent
        # inadvertent captures of free identifiers.
        # 
        def expand(template, matches, depth = 0, inspection = false)
          case template
          
            when Cons then
              result, last, repeater, template_pair = nil, nil, nil, template
              
              push = lambda do |value|
                return if value == Cons::NULL
                pair = Cons.new(value)
                result ||= pair
                last.cdr = pair if last
                last = pair
              end
              
              while not template_pair.null?
                cell = template_pair.car
                followed_by_ellipsis = (template_pair.cdr.car.to_s == ELLIPSIS)
                dx = followed_by_ellipsis ? 1 : 0
                
                matches.inspecting(depth + 1) if followed_by_ellipsis and
                                                 not inspection
                
                repeater = cell if followed_by_ellipsis
                
                if cell.to_s == ELLIPSIS and not inspection
                  matches.expand! { push[expand(repeater, matches, depth + 1)] }
                  matches.depth = depth
                else
                  inspect = inspection || (followed_by_ellipsis && depth + 1)
                  value = expand(cell, matches, depth + dx, inspect)
                  push[value] unless inspect
                end
                
                template_pair = template_pair.cdr
              end
              result
          
            when Identifier then
              return matches.get(template) if matches.defined?(template)
              return Identifier.new(template) unless @hygienic
              
              @lexical_scope.defined?(template) ?
                  Binding.new(template, @lexical_scope, false) :
                  rename(template)
          
            else
              template
          end
        end
        
        def rename(id)
          return id unless @calling_scope.defined?(id)
          i = 1
          i += 1 while @calling_scope.defined?("#{id}#{i}")
          Identifier.new("#{id}#{i}")
        end
      end
      
    end
  end
end

