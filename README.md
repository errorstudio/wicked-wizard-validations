# Wicked::Wizard::Validations - a validation mixin for Wicked
This is a mixin for [the Wicked wizard gem](https://github.com/schneems/wicked) which makes it easier to conditionally validate your models based on where the user is in the wizard process.

## Why would I want to use this?
We often come up against a situation where you want to validate the data is entering into a wizard form, but only the fields they have seen already. Imagine this 3-step process:

1. First name, last name, email
2. Password, Password Confirmation
3. Contact details

If the user were at step 1, it would be useless having a basic model validation requiring password be completed: they haven't seen that field yet.
 
So what we want to do is _conditionally validate_ the fields, based on the user's progress. We do this by creating a class method for each step you want to validate, with a hash to pass to the validator.

__Note:__ this requires the step the user is on to be stored in the user model.

## Installation

Add this line to your application's Gemfile:

    gem 'wicked-wizard-validations'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wicked-wizard-validations

## Usage
For the purposes of this demo, we'll assume you're validating a model called `User`. Of course, your model could be called anything, and there's no reason why you can't validate several models at one using a common set of steps.

### Create your model
Create an ActiveRecord model as normal. This gem looks for a string field called `current_step` (which is configurable - see below).

### Define your wizard steps.
The easiest place to define your wizard steps is in your model. This is a departure from the normal Wicked::Wizard way of doing it, which is in the controller

```
class User < ActiveRecord::Base
    include Wicked::Wizard::Validations
    
    #This method defines the step names. You still need to call `step` in the controller.
    def self.wizard_steps
        [
            "basic_details",
            "password",
            "contact_details"
        ]
    end
```

```
class UsersController < ApplicationController
    include Wicked::Wizard
    # This is the 'normal' place to define Wicked::Wizard steps.
    # We just call the steps we defined above in User.
    steps(*User.wizard_steps)    
end
```

### Add your validations for each step
Ok, so now you have steps, and the controller knows about them. How do you add validations?

You create _class_ methods on `User` which correspond to the name of the step, with `_validations` at the end. This method needs to return a hash of field names and keys, the latter of which which is passed straight to [Activerecord Validations](http://guides.rubyonrails.org/active_record_validations.html).

```
class User < ActiveRecord::Base
    include Wicked::Wizard::Validations
    
    #This method defines the step names
    def self.wizard_steps
        [
            "basic_details",
            "password",
            "contact_details"
        ]
    end
    
    
    def self.basic_details_validations    # validations for the basic_details step.
        {
            first_name: {
                presence: {
                    message: "Don't be shy! We need your first name."
                }
            },
            last_name: {
                presence: true  #just the default ActiveRecord validation message
            },
            email: {
                presence: true, on: :update #this validation only happens on update, not create.
            }
        }
    end
```

### Set up validations
The last stage is to set up the validations when the model is loaded. That's a one-liner in the model:

```
    class User < ActiveRecord::Base
        include Wicked::Wizard::Validations
        
        # Setup the validations when this class is loaded
        self.setup_validations!
        
        #other stuff in here
    end
    
```

And that's it! For a given step, defined validations will apply whenever a user is at or past that step.

### Customising the `current_step` and `wizard_steps` methods.
You might want to have a different attribute on your model to store the current step. That's easy:

```
    class User < ActiveRecord::Base
        include Wicked::Wizard::Validations
        
        self.current_step_method = :my_current_step_attribute #the current step will be stored in this attribute.
        
        #other stuff in here
    end
```

Likewise, the you might want to define a different method for the wizard steps:

```
    class User < ActiveRecord::Base
        include Wicked::Wizard::Validations
        
        self.wizard_steps_method = :my_amazing_steps # User.my_amazing_steps needs to return an array of steps
        
        #other stuff in here
    end
```

### Validating more than one model in a wizard
You might have a relationship between models, and be collecting data for both in a wizard. That's pretty easy to support: you just have to remember to use the same list of wizard steps.

Say, for example, that your user has an `address`, you could require a house name and postcode when they get to the `contact_details` step (or after it).

```
    class Address < ActiveRecord::Base
        include Wicked::Wizard::Validations
       
        belongs_to :user
        
        #returns the current step for the associated user
        def current_step
            user.current_step 
        end
        
        # returns the wizard steps for the User class
        def wizard_steps
            User.wizard_steps
        end
        
        # Specify validations on Address which should apply when the user is on or past 
        # the address_details step
        def address_details_validations
            house_name_or_number: {
                presence: {
                    message: "Please give us your house name or number"
                }
            },
            postcode: {
                format: {
                    with: /^([A-PR-UWYZ0-9][A-HK-Y0-9][AEHMNPRTVXY0-9]?[ABEHMNPRVWXY0-9]? {1,2}[0-9][ABD-HJLN-UW-Z]{2}|GIR 0AA)$/
                }
            }
        end
    end
     
```

### Utility instance methods
There are a couple of instance methods on objects which have this mixin applied.

```
u = User.find(123)
u.current_wizard_step # get the current step
u.previous_wizard_steps #the steps before the one the user is on
u.current_and_previous_wizard_steps #an array of steps the user has been through
```

### Redirecting to the right step on login
Because we're storing the current step of the user, you get the ability to allow the user to jump back to the step they were on when they log in. Very useful for big multi-page forms where the user might need to come back later.

In the controller you're using for your wizard, you need this in the `show` method:

```
    class UsersController < ApplicationController
        include Wicked::Wizard
        
        # other stuff
        
        def show
            @user = current_user
            
            # Redirect to the user's current step - useful for logging in a second time
            if @user.current_wizard_step.present? && !@user.current_and_previous_wizard_steps.include?(step)
                jump_to(@user.current_wizard_step)
            end
        end
    end
```

#### Allowing users to go back in the process
If you redirect the user to their previously-stored step, you've just stopped them from going back in the process. So to get around that, we need to update their current step when they change it.

Note that this only allows the user to go to steps earlier than the one they're on.

```
    class UsersController < ApplicationController
        include Wicked::Wizard
        
        # other stuff
        
        def show
            @user = current_user
            
            # Redirect to the user's current step - useful for logging in a second time
            if @user.current_wizard_step.present? && !@user.current_and_previous_wizard_steps.include?(step)
                jump_to(@user.current_wizard_step)
            end
            
            # if the step we're rendering is before the users last known current step, assume they've clicked their
            # browser's back button, update their current_step and render that page of the wizard
            if (User.wizard_steps.index(step) < User.wizard_steps.index(@user.current_wizard_step.to_sym))
              @user.update_attribute(:current_step, step) # if your attribute is called something else, you'll need to amend this.
            end
        end
    end
```

## Contributing

1. Fork it ( https://github.com/errorstudio/wicked-wizard-validations/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Squash your commits into logical changesets.
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
