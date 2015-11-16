require "wicked/wizard/validations/version"

module Wicked
  module Wizard
    module Validations
      extend ActiveSupport::Concern

      included do
        class << self
          # Set up a class-level instance method to hold the name of a method to call
          # to get the current_step for this model.
          attr_accessor :current_step_method, :wizard_steps_method
        end
      end

      #
      #Class methods on the included model
      #
      module ClassMethods

        # @return [Array] a list of wizard steps for the class. Calls the method specified in the class instance attribute
        # `wizard_steps_method`; returns an empty [Array] otherwise.
        def all_wizard_steps
          meth = self.wizard_steps_method
          if meth.present?
            case meth.class.to_s
              when "Symbol"
                self.send(meth)
              else
                raise ArgumentError, "wizard_steps_method accepts only a symbol, which should be a class method name"
            end
          else
            begin
              wizard_steps #if no wizard_steps_method set, assume `wizard_steps`.
            rescue
              []
            end
          end

        end

        # get previous steps for a given step
        # @param step [Symbol] the name of the step you're on now
        # @return [Array] the steps prior to this one
        def previous_wizard_steps(step)
          #cast the incoming step to a symbol
          step = step.to_sym if step.is_a?(String)
          self.all_wizard_steps.slice(0,self.all_wizard_steps.index(step))
        end

        # This is where the meat of the work happens.
        # We call this in the class, and it iterates through all the wizard steps, calling `[wizard_step_name]_validations`
        # on the class. If it responds, it should return a hash which can be passed straight into a `validates()` call
        def setup_validations!
          # Iterate through each step in the validations hash, and call a class method called [step]_step_validations
          # if it exists. For example, if step were called foo_details, the method would be called foo_details_validations
          self.all_wizard_steps.each do |step|
            validation_method_name = "#{step}_validations".to_sym
            if self.respond_to?(validation_method_name)
              #if the method responds, we're expecting a hash in the following format:
              # {
              #   field_name: {
              #     presence: true
              #   }
              # }
              self.send(validation_method_name).each do |field,validations|
                # validate the field, using the validations hash, but merge in a lambda which checks whether the object
                # is at the step yet, or not. If it's not, the validation isn't applied.
                validates field, validations.merge({if: ->{ self.current_and_previous_wizard_steps.include?(step)}})
              end
            end
          end
        end
      end

      #
      #instance methods on the model follow
      #

      # Get the current wizard step by calling the instance method specified
      # in the class; fall back to calling `current_step` on the instance.
      def current_wizard_step
        meth = self.class.current_step_method
        if meth.present?
          case meth.class.to_s
            when "Symbol"
              self.send(meth)
            else
              raise ArgumentError, "current_step_method accepts a symbol, which should be the name of a callable instance method"
          end
        else
          #assume the method is called current_step() and call that
          current_step
        end
      end

      # Call the `previous_wizard_steps` class method, passing in the current step for this instance
      # @return [Array] an ordered list of wizard steps which happen before the current one
      def previous_wizard_steps
        self.class.previous_wizard_steps(current_wizard_step.to_sym)
      end

      # @return [Array] an ordered list of wizard steps, up to and including this one
      def current_and_previous_wizard_steps
        previous_wizard_steps.push(current_wizard_step.to_sym)
      end
    end
  end
end
