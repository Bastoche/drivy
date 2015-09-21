
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

  def initialize(json)
    @id = json["id"]
    @car_id = json["car_id"]
    @start_date = Date.parse(json["start_date"])
    @end_date = Date.parse(json["end_date"])
    @distance = json["distance"]
    @deductible_reduction = json["deductible_reduction"]
  end

  def days
    1 + (end_date - start_date).to_i
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
  def initialize(who, amount)
    @who = who    
    @amount = amount.abs
    @type = amount > 0 ? "credit" : "debit"
  end

  def to_hash
    { :who => @who, :type => @type, :amount => @amount }
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

def output(rental, cars)
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

  { :id => rental.id, :actions => actions.map{ |action| action.to_hash } }
end

# read data from input json file
data = File.read("data.json")
json = JSON.parse(data)

# parse the json into car and rental objects
carsJson = json["cars"]
cars = carsJson.map { |carJson| Car.new(carJson) }

rentalsJson = json["rentals"]
rentals = rentalsJson.map { |rentalJson| Rental.new(rentalJson) }

# compute the needed result
result = { :rentals => rentals.map { |rental| output(rental, cars) } }

# write the result to the output file, add a line feed to match the provided file
File.write("output.json", JSON.pretty_generate(result) + "\n")