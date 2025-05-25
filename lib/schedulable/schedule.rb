module Schedulable
  module Model
    class Schedule < ActiveRecord::Base
      self.table_name = 'schedules'

      # Use Rails 7.2+ serialization
      serialize :day, coder: YAML
      serialize :day_of_week, coder: YAML

      belongs_to :schedulable, polymorphic: true

      after_initialize :update_schedule
      before_save :update_schedule

      validates :rule, presence: true
      validates :time, presence: true
      validates :date, presence: true, if: -> { rule == 'singular' }
      validate :validate_day, if: -> { rule == 'weekly' }
      validate :validate_day_of_week, if: -> { rule == 'monthly' }

      delegate_missing_to :@schedule, allow_nil: true

      def to_icecube
        @schedule
      end

      def to_s
        if rule == 'singular'
          # Return formatted datetime for singular rules
          datetime = date.to_datetime + time.seconds_since_midnight.seconds
          I18n.localize(datetime, format: :long)
        else
          # Return formatted schedule for recurring rules
          to_icecube.to_s
        end
      end

      def self.param_names
        [
          :id, :date, :time, :time_end, :rule, :until, :count, :interval,
          { day: [], day_of_week: { 
            monday: [], tuesday: [], wednesday: [], 
            thursday: [], friday: [], saturday: [], sunday: [] 
          }}
        ]
      end

      private

      def update_schedule
        if rule && date && time
          # Get schedule-object
          @schedule = IceCube::Schedule.new(date.to_datetime + time.seconds_since_midnight.seconds)

          case rule
          when 'singular'
            # No recurrence rule
          when 'weekly'
            days = day.map(&:to_sym) if day
            @schedule.add_recurrence_rule(IceCube::Rule.weekly(interval).day(*days)) if days
          when 'monthly'
            days = day_of_week.map do |weekday, week_numbers|
              week_numbers.map do |week_number|
                IceCube::Rule.monthly(interval).day_of_week(weekday.to_sym => [week_number])
              end
            end.flatten
            @schedule.add_recurrence_rule(IceCube::Rule.monthly(interval).day_of_week(days)) if days
          end

          # Add exceptions
          @schedule.add_exception_time(date.to_datetime + time.seconds_since_midnight.seconds) if rule != 'singular'
        end
      end

      def validate_day
        if rule == 'weekly' && day.empty?
          errors.add(:day, :empty)
        end
      end

      def validate_day_of_week
        if rule == 'monthly' && day_of_week.empty?
          errors.add(:day_of_week, :empty)
        end
      end
    end
  end
end
