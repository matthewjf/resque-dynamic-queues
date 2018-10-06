module Resque
  module Plugins
    module DynamicQueues
      module Queues

        class DynamicPattern
          attr_reader :queue, :negated, :pattern
          def initialize(queue)
            @queue = queue
            @negated = queue =~ /^!/
            patrstr = (@negated ? queue[1..-1] : queue).gsub(/\*/, ".*")
            @pattern = /^#{patrstr}$/
          end
        end

        def queues_with_dynamic
          queue_names = @queues.dup

          return queues_without_dynamic if queue_names.grep(/(^!)|(^@)|(\*)/).size == 0

          real_queues = Resque.queues.sort
          matched_queues = []

          dynamic_queues = queue_names.map { |q| DynamicPattern.new q }

          sort_hash = {}

          stable_sort_constant = 10**(real_queues.length.to_s.length)

          real_queues.select.with_index do |q, i|
            negated = false
            matched = false
            max_length = 0
            match_index = -1
            dynamic_queues.each.with_index do |dq, j|
              if dq.pattern =~ q
                negated ||= dq.negated
                matched = true
                if dq.queue.length > max_length
                  match_index = (j * stable_sort_constant) + i
                  max_length = dq.queue.length
                end
              end
            end
            sort_hash[q] = match_index
            matched && !negated
          end
          .sort_by { |q| sort_hash[q] }
        end

        def self.included(receiver)
          receiver.class_eval do
            alias queues_without_dynamic queues
            alias queues queues_with_dynamic
          end
        end

      end
    end
  end
end
