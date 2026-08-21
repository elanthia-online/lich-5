# frozen_string_literal: true

require 'spec_helper'
require 'gemstone/critranks'

module Lich
  module Gemstone
    describe CritRanks do
      # Every record reachable through the table, skipping the nil placeholder
      # rows some tables carry.
      def each_record
        described_class.table.each_value do |typedata|
          typedata.each_value do |locdata|
            next if locdata.nil?
            locdata.each_value do |record|
              next if record.nil?
              yield record
            end
          end
        end
      end

      it 'loads and indexes the crit tables at require time without raising' do
        # Some tables contain explicit nil location/rank rows (e.g. grapple
        # right_eye); init must tolerate them. Reaching this example at all
        # proves the require above did not raise, but exercise reload! too.
        expect { described_class.reload! }.not_to raise_error
        expect(described_class.table).not_to be_empty
      end

      it 'has a regex for every non-nil record' do
        each_record do |record|
          expect(record[:regex]).to be_a(Regexp), "record missing :regex: #{record.inspect}"
        end
      end

      describe '.parse' do
        # Records whose regex is a plain anchored literal can be turned back
        # into a matching input line, giving us real table-driven fixtures.
        def literal_records(limit)
          found = []
          each_record do |record|
            source = record[:regex].source
            body = source.sub(/\A\^/, '').sub(/\$\z/, '')
            next if body =~ /[\\\[\](){}.*+?|]/
            found << [record, body]
            break if found.size >= limit
          end
          found
        end

        it 'finds the same matches as an exhaustive scan of every pattern' do
          all_records = []
          each_record { |record| all_records << record }

          literal_records(200).each do |record, line|
            expected = all_records.select { |r| r[:regex] =~ line }
            result = described_class.parse(line)
            expect(result.values).to match_array(expected)
            expect(result.values).to include(record)
          end
        end

        it 'matches lines with leading whitespace (strip support)' do
          record, line = literal_records(1).first
          expect(described_class.parse("   #{line}  ").values).to include(record)
        end

        it 'returns an empty hash for non-crit lines' do
          expect(described_class.parse('You swing a battle axe at a triton brawler!')).to be_empty
          expect(described_class.parse('')).to be_empty
          expect(described_class.parse('   ')).to be_empty
        end

        it 'does not grow the index when probed with unknown words' do
          before_keys = described_class.instance_variable_get(:@index_buckets).size
          described_class.parse('Zzyzx unknownword line!')
          after_keys = described_class.instance_variable_get(:@index_buckets).size
          expect(after_keys).to eq(before_keys)
        end
      end
    end
  end
end
