require 'watir-webdriver'

class Razor
  attr_reader :webdriver
  def initialize(options={})
    @webdriver = Watir::Browser.new(options[:blade] || :firefox)
    ObjectSpace.define_finalizer( self, self.class.finalize(@webdriver) )
  end
  def goto(url)
    @webdriver.goto(url)
  end
  def url
    @webdriver.url
  end
  def enter_text(xpath, text)
    @webdriver.text_field(:xpath, xpath).set text
  end
  def submit
    @webdriver.form(:xpath, "//form").submit
  end
  def click(xpath)
    @webdriver.element_by_xpath(xpath).click
  end
  def shave(options={}, &block)
    Shave.new(@webdriver, options, &block).evaluate
  end
  def self.finalize(webdriver)
    proc { webdriver.close }
  end
end

class Shave
  def initialize(webdriver, options, &block)
    @webdriver = webdriver
    @options = options
    @options[:number_of_steps]||=10
    @options[:step_time]||=0.5
    @arrays = []
    @values = []
    self.instance_eval &block
  end

  def value(name, xpath, &block)
    @values << [name,xpath,block]
  end

  def array(name, xpath, &block)
    @arrays << [name,xpath,block]
  end

private
  # Because of the fact that selenium doesn't wait for the page to load,
  # we continuously poll every :step_time seconds for a :number_of_steps
  def evaluate_values
    result = {}
    @values.each do |name, xpath, block|
      try_and_sleep_on_fail do
        result[name] = process_value(xpath,block)
      end
    end
    result
  end

  def process_value(xpath, block)
    element = @webdriver.element_by_xpath(xpath)
    block == nil ? element : block.call(element)
  end

  def try_and_sleep_on_fail
    success = false
    @options[:number_of_steps].times do
      begin
        x = yield
        if(x.is_a?(Array) && x.length==0)
          sleep @options[:step_time]
          next
        end
        success=true
        break
      rescue Exception
        sleep @options[:step_time]
      end
    end
    yield unless success
  end

  def evaluate_arrays
    result={}
    @arrays.each do |name, xpath, block|
      try_and_sleep_on_fail do
        result[name] = process_array(xpath, block)
      end
    end
    result
  end

  def process_array(xpath, block)
    @webdriver.elements_by_xpath(xpath).map do |element|
      block == nil || element == nil ? element : block.call(element)
    end
  end

  def evaluate
    result = {}
    result.merge!(evaluate_values)
    result.merge!(evaluate_arrays)
    result
  end
end
