
require "date"
require "json"

DEDUCTIBLE_REDUCTION_PRICE_PER_DAY = 400

class Car
  attr_reader :id, :price_per_day, :price_per_km

  def initialize(json)
    @id = json["id"]
    @price_per_day = json["price_per_day"]
    @price_per_km = json["price_per_km"]
  end
end

class Rental
  attr_reader :id, :car_id, :start_date, :end_date, :distance, :deductible_reduction

  def self.from_json(json)
    self.new(json["id"], json["car_id"], Date.parse(json["start_date"]), Date.parse(json["end_date"]), json["distance"], json["deductible_reduction"])
  end

  def initialize(id, car_id, start_date, end_date, distance, deductible_reduction)
    @id = id
    @car_id = car_id
    @start_date = start_date
    @end_date = end_date
    @distance = distance
    @deductible_reduction = deductible_reduction
  end

  def days
    1 + (end_date - start_date).to_i
  end
end

class RentalModification
  attr_reader :id, :rental_id, :start_date, :end_date, :distance

  def initialize(json)
    @id = json["id"]
    @rental_id = json["rental_id"]
    @start_date = Date.parse(json["start_date"]) if json["start_date"]
    @end_date = Date.parse(json["end_date"]) if json["end_date"]
    @distance = json["distance"]
  end

  def create_modified_rental(rental)
    new_start_date = @start_date ? @start_date : rental.start_date
    new_end_date = @end_date ? @end_date : rental.end_date
    new_distance = @distance ? @distance : rental.distance
    Rental.new(rental.id, rental.car_id, new_start_date, new_end_date, new_distance, rental.deductible_reduction)
  end
end

class Fees
  attr_reader :insurance_fee, :assistance_fee, :drivy_fee

  def initialize(insurance_fee, assistance_fee, drivy_fee)
    @insurance_fee = insurance_fee
    @assistance_fee = assistance_fee
    @drivy_fee = drivy_fee
  end
end

class Action
  attr_reader :who, :amount

  def initialize(who, amount)
    @who = who    
    @type = amount > 0 ? "credit" : "debit"
    @amount = amount       
  end

  def diff(action)
    Action.new(@who, @amount - action.amount)
  end

  def to_hash
    { :who => @who, :type => @type, :amount => @amount.abs }
  end
end

def compute_price_for_days(price_per_day, days)
  days_full_price = 1
  days_10_percent_off = [[0, days - 1].max, 4 - 1].min
  days_30_percent_off = [[0, days - 4].max, 10 - 4].min
  days_50_percent_off = [0, days - 10].max

  part_full_price = days_full_price * price_per_day    
  part_10_percent_off = days_10_percent_off * price_per_day * 0.9    
  part_30_percent_off = days_30_percent_off * price_per_day * 0.7
  part_50_percent_off = days_50_percent_off * price_per_day * 0.5

  result = part_full_price + part_10_percent_off + part_30_percent_off + part_50_percent_off

  result.round
end

def compute_price(rental, car)    
  price_for_days = compute_price_for_days(car.price_per_day, rental.days)
  price_for_kms = rental.distance * car.price_per_km      
  price_for_days + price_for_kms
end

def compute_fees(price, days)
  total = (price * 0.3).round
  insurance_fee = total / 2
  assistance_fee = days * 100
  drivy_fee = total - insurance_fee - assistance_fee 
  Fees.new(insurance_fee, assistance_fee, drivy_fee)
end

def compute_option(rental) 
  rental.deductible_reduction ? rental.days * DEDUCTIBLE_REDUCTION_PRICE_PER_DAY : 0  
end

def compute_driver_action(price, option)
  amount = - price - option
  Action.new("driver", amount)
end

def compute_owner_action(price, fees)
  amount = price - fees.insurance_fee - fees.assistance_fee - fees.drivy_fee
  Action.new("owner", amount)
end

def compute_insurance_action(fees)  
  Action.new("insurance", fees.insurance_fee)
end

def compute_assistance_action(fees)  
  Action.new("assistance", fees.assistance_fee)
end

def compute_drivy_action(fees, option)  
  amount = fees.drivy_fee + option
  Action.new("drivy", amount)
end

def actions_for_rental(rental, cars)
  car = cars.find { |car| car.id == rental.car_id }
  price = compute_price(rental, car)
  fees = compute_fees(price, rental.days)
  option = compute_option(rental)

  actions = Array.new()
  actions.push(compute_driver_action(price, option))
  actions.push(compute_owner_action(price, fees))
  actions.push(compute_insurance_action(fees))
  actions.push(compute_assistance_action(fees))
  actions.push(compute_drivy_action(fees, option))
end

def actions_for_modification(rental_modification, rentals, cars) 
  original_rental = rentals.find { |rental| rental.id == rental_modification.rental_id }
  modified_rental = rental_modification.create_modified_rental(original_rental)

  original_actions = actions_for_rental(original_rental, cars)
  modified_actions = actions_for_rental(modified_rental, cars)
  
  delta_actions = ["driver", "owner", "insurance", "assistance", "drivy"].map { |who| 
    modified_actions.find { |action| action.who == who }.diff original_actions.find { |action| action.who == who }
  }
end

def output(rental_modification, rentals, cars)
  actions = actions_for_modification(rental_modification, rentals, cars)
  { :id => rental_modification.id, :rental_id => rental_modification.rental_id, :actions => actions.map{ |action| action.to_hash } }
end  

# read data from input json file
data = File.read("data.json")
json = JSON.parse(data)

# parse the json into car and rental objects
cars_json = json["cars"]
cars = cars_json.map { |car_json| Car.new(car_json) }

rentals_json = json["rentals"]
rentals = rentals_json.map { |rental_json| Rental.from_json(rental_json) }

rental_modifications_json = json["rental_modifications"]
rental_modifications = rental_modifications_json.map { |rental_modification_json| RentalModification.new(rental_modification_json) }

# compute the needed result
result = { :rental_modifications => rental_modifications.map { |rental_modification| output(rental_modification, rentals, cars) } }

# write the result to the output file, add a line feed to match the provided file
File.write("output.json", JSON.pretty_generate(result) + "\n")