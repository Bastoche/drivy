
require "date"
require "json"

class Car
  attr_reader :id, :price_per_day, :price_per_km

  def initialize(json)
    @id = json["id"]
    @price_per_day = json["price_per_day"]
    @price_per_km = json["price_per_km"]
  end
end

class Rental
  attr_reader :id, :car_id, :start_date, :end_date, :distance

  def initialize(json)
    @id = json["id"]
    @car_id = json["car_id"]
    @start_date = Date.parse(json["start_date"])
    @end_date = Date.parse(json["end_date"])
    @distance = json["distance"]
  end

  def price(cars)
    car = cars.find { |car| car.id == car_id }
    days = 1 + (end_date - start_date).to_i    
    price_for_days = days * car.price_per_day  
    price_for_kms = distance * car.price_per_km    
    price = price_for_days + price_for_kms
  end
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
result = { :rentals => rentals.map { |rental| {:id => rental.id, :price => rental.price(cars)} } }

# write the result to the output file, add a line feed to match the provided file
File.write("output.json", JSON.pretty_generate(result) + "\n")