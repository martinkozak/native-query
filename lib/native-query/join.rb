# encoding: utf-8
require "native-query/query"
require "hash-utils/object"   # >= 0.17.0
require "hash-utils/array"
require "hash-utils/string"   # >= 0.18.0

module NativeQuery

    ##
    # Represents join request.
    #
     
    class Join
    
        ##
        # Indicates table to join from.
        #
        
        @original
    
        ##
        # Indicates table to join.
        #
        
        @table
        
        ##
        # Indicates fields for select.
        #
        
        @fields
        
        ##
        # Holds joins specifiaction.
        #
        
        @joins
        attr_reader :joins
        
        ##
        # Holds join conditions.
        #
        
        @where
        
        ##
        # Indicates type of joining.
        # Possible values are:
        #
        #  * :indirect for M:N relation,
        #  * :direct for 1:N relation
        #
        
        @type
        
        ##
        # Contains indirect joining manual specification.
        #
        
        @indirect
        
        ##
        # Holds specificarion of direct joining.
        #
        
        @direct
        
        ##
        # Constructor.
        #
        
        def initialize(original, table)
            @table = table
            @original = original
            @fields = [ ]
            @where = [ ]
            @joins = [ ]
            @type = :direct
            
            @indirect_source = original
        end
        
        ##
        # Sets hash for select from joined table.
        # Without arguments returns fields list. 
        #
        
        def fields(*args)
            if args.empty?
                result = { }
                @fields.each do |i|
                    if not i.kind_of? Hash
                        i = {i => i}
                    end
                    
                    i.each_pair do |from, to|
                        result[__fix_field(from)] = @table.to_s << "_" << to.to_s
                    end
                end
                
                return result
            else
                @fields += args
                return self
            end
        end
        
        ##
        # Selects where conditions to load.
        #
        
        def where(*args)
            @where << args
            return self
        end
        
        ##
        # Indicates indirect joining. (M:N)
        #
        
        def indirect(*args)
            @type = :indirect
            if args.first.array? and (args.first.first == :backward) and (args.first.second.array?)
                @indirect = args.first
            else
                @indirect = args
            end
            
            return self
        end
        
        ##
        # Indicates direct joining. (1:M)
        #
        
        def direct(*args)
            @type = :direct
            if args.first.array? and (args.first.first == :backward) and (args.first.second.array?)
                @direct = args.first
            else
                @direct = args
            end
            
            return self
        end
        
        ##
        # Indicates backward joining.
        #
        
        def backward(*args)
            @direct = [:backward, args]
        end
           
        ##
        # Builds ON join string.
        #
        
        def build
            result = nil
            
            case @type
                when :indirect
                    result = __indirect
                when :direct
                    result = __direct
            end
            
            return result
        end
        
        ##
        # Return wheres.
        #
        
        def wheres
            self._fix_where
        end
        
        ##
        # Calls mapping to joins specification. Call name is name of 
        # the target table.
        #
        # Block works by the same way as query, but for join. But 
        # intra-join calls doesn't work because it returns Query too.
        #
        
        def method_missing(sym, *args, &block)
            join = self.class::new(@table, sym)

            if args and not args.empty?
                join.fields(*args)
            end

            join.instance_eval(&block)
            @joins << join
            
            return self
        end
        
        ##
        # Fixes field name. Joins table name if SQL table joining
        # required.
        #
        
        private
        def __fix_field(name, formatted = false)
            NativeQuery::Query::fix_field(name, @table, formatted)
        end

        
        ##
        # Fixes where specification(s) if it's hash with symbol key.
        #
        
        protected
        def _fix_where
            NativeQuery::Query::fix_conditions(@where) do |arg|
                #p args
                #args.each do |i|
                #    __fix_field(i)
                #end
                __fix_field(arg)
            end
        end
        
        ##
        # Builds indirect join.
        #
        
        private
        def __indirect

            if (@indirect.first == :backward) and (@indirect.second.array?)
                backward = true
                indirect = @indirect.second
            else
                backward = false
                indirect = @indirect
            end
            
            ##
            
            result = { }
            to = @table.to_s
            from = @original.to_s
            arg1, arg2, arg3 = indirect

            # automatic joining
            if indirect.empty?
                from.swap_with(to) if backward
                through = from + "_" + to
                joining_table = through.to_sym
                result[joining_table] = "[" << from << ".id] = [" << through << "." << from << "_id]"
                result[@table] = "[" << through << "." << to << "_id] = [" << to << ".id]"
                
            # standard specification (semiautomatic joining)
            elsif arg1.symbol? and arg2.hash?
                through = arg1.to_s
                joining_table = arg1
                result[joining_table] = "[" << from << "." << arg2.keys.first.to_s << "] = [" << through << "." << from << "_id]"
                result[@table] = "[" << through << "." << to << "_id] = [" << to << "." << arg2.values.first.to_s << "]"
                
            # fluent query specification (manual joining)
            elsif arg1.symbol? and arg2.string? and arg3.string?
                joining_table = arg1
                result[joining_table] = arg2
                result[@table] = arg3
            
            # error
            else
                raise Exception::new("Symbol and Hash or Symbol and two Strings expected.")
                
            end
            
            return result
        end
        
        ##
        # Builds direct join.
        #
        
        private
        def __direct
            
            if @direct.array? and (@direct.first == :backward) and (@direct.second.array?)
                backward = true
                direct = @direct.second
            else
                backward = false
                direct = [ ]
            end
            
            ##
            
            empty = direct.empty?
            direct = direct.first
            from = @original.to_s
            to = @table.to_s
            result = { }
            
            # automatic joining
            if empty
                from.swap_with(to) if backward
                result[@table] = "[" << from << ".id] = [" << to << "." << from << "_id]"
            # manual joining
            elsif direct.hash?
                result[@table] = "[" << from << "." << direct.keys.first.to_s << "] = [" << to << "." << direct.values.first.to_s << "]"
            # special joining
            elsif direct.string?
                result[@table] = direct
            # error
            else
                raise Exception::new("Hash or String expected.")
            end
            
            return result
        end            
    end
end
