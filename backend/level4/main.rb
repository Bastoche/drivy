
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

  def price_for_days(days)
    days_full_price = 1
    days_10_percent_off = [[0, days - 1].max, 4 - 1].min
    days_30_percent_off = [[0, days - 4].max, 10 - 4].min
    days_50_percent_off = [0, days - 10].max

    part_full_price = days_full_price * @price_per_day    
    part_10_percent_off = days_10_percent_off * @price_per_day * 0.9    
    part_30_percent_off = days_30_percent_off * @price_per_day * 0.7
    part_50_percent_off = days_50_percent_off * @price_per_day * 0.5

    result = part_full_price + part_10_percent_off + part_30_percent_off + part_50_percent_off

    result.round
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

def compute_price(rental, car)    
  price_for_days = car.price_for_days(rental.days)
  price_for_kms = rental.distance * car.price_per_km      
  price_for_days + price_for_kms
end

def compute_commission(price, days)
  total = (price * 0.3).round
  insurance_fee = total / 2
  assistance_fee = days * 100
  drivy_fee = total - insurance_fee - assistance_fee 
  { :insurance_fee => insurance_fee, :assistance_fee => assistance_fee, :drivy_fee => drivy_fee } 
end

def compute_option(rental) 
  option_price = rental.deductible_reduction ? rental.days * DEDUCTIBLE_REDUCTION_PRICE_PER_DAY : 0
  { :deductible_reduction => option_price } 
end

def output(rental, cars)
  car = cars.find { |car| car.id == rental.car_id }
  price = compute_price(rental, car)
  commission = compute_commission(price, rental.days)
  option = compute_option(rental)
  {:id => rental.id, :price => price, :options => option, :commission => commission}
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