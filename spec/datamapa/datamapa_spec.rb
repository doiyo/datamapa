require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
require 'mocha/setup'
require 'bourne'
require 'datamapa'

describe DataMapa do

  class MapperStub
  end

  def ar_class_with_attributes(attributes)
    Class.new do
      attributes.each do |attr|
        attr_accessor attr
      end

      def initialize(id=nil)
        @id = id
      end

      def self.update(id, hash)
      end
    end
  end

  def class_with_attributes(attributes)
    Class.new do
      attributes.each do |attr|
        attr_accessor attr
      end

      def initialize(id=nil)
        @id = id
      end
    end
  end

  def mapper_class(class_name, attributes)
    Class.new do
      include DataMapa

      active_record_class attributes[:active_record_class]
      creates_model_with &attributes[:creates_model_with]
      simple_attr attributes[:simple_attr] if attributes[:simple_attr]
      ref_attr attributes[:ref_attr] if attributes[:ref_attr]
      semantic_key attributes[:semantic_key] if attributes[:semantic_key]
      composed_of attributes[:composed_of] if attributes[:composed_of]
      composes attributes[:composes] if attributes[:composes]
      aggregates attributes[:aggregates] if attributes[:aggregates]

      # Provide name because this mapper class is anonymous
      define_singleton_method :name do
        class_name
      end
    end
  end

  let (:any_id) { 1 }
  let (:any_object) { Object.new }

  describe "simple attribute" do
    let(:ar_class) { ar_class_with_attributes([:id, :attribute]) }
    let(:model_class) { class_with_attributes([:id, :attribute]) }
    let(:mapper) do
      mapper_class(
        'SimpleMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        simple_attr: [:attribute]
      )
    end

    it "finds model" do
      id = any_id
      result_ar = ar_class.new(id)
      result_ar.attribute = 'any string'

      ar_class.stubs(:find).with(id).returns(result_ar)

      model = mapper.find!(id)

      model.id.must_equal result_ar.id
      model.attribute.must_equal result_ar.attribute
    end

    it "creates object" do
      model = model_class.new
      model.attribute = 'any string'

      id = any_id
      ar = ar_class.new(id)
      ar_class.expects(:create!).with(attribute: model.attribute).returns(ar)

      returned_model = mapper.create!(model)

      model.id.must_equal id
      returned_model.id.must_equal id
    end

    it "updates object" do
      id = any_id
      model = model_class.new(id)
      model.attribute = 'any string'

      ar_class.expects(:update).with(id, attribute: model.attribute)

      mapper.update(model)
    end

    it "saves new object" do
      model = model_class.new
      model.attribute = 'any string'

      id = any_id
      ar = ar_class.new(id)
      ar_class.expects(:create!).with(attribute: model.attribute).returns(ar)

      mapper.save!(model)

      model.id.must_equal id
    end

    it "saves existing object" do
      model = model_class.new(any_id)
      model.attribute = 'any string'

      ar_class.expects(:update).with(model.id, attribute: model.attribute)

      mapper.save!(model)
    end
  end

  describe "ref attribute" do
    let(:model_class) { class_with_attributes([:id, :object   ]) }
    let(:ar_class)    { ar_class_with_attributes([:id, :object_id]) }
    let(:ref_mapper) { MapperStub }
    let(:mapper) do
      mapper_class(
        'RefMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        ref_attr: { object: ref_mapper }
      )
    end
    
    it "creates model from ar" do
      object = any_object
      ref_mapper.stubs(:find!).returns(object)

      ar = ar_class.new(any_id)

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
      model.object.must_equal object
    end

    it "maps when creating object" do
      model = model_class.new
      model.object = stub(id: 10)

      id = any_id
      ar = ar_class.new(id)

      ar_class.expects(:create!).with(object_id: model.object.id).returns(ar)

      mapper.create!(model)

      model.id.must_equal id
    end
  end

  describe "aggregation" do
    let(:ar_class) { ar_class_with_attributes([:id, :components]) }
    let(:model_class) { class_with_attributes([:id, :components]) }
    let(:mapper) do
      mapper_class(
        'AggregateMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        aggregates: { components: MapperStub }
      )
    end 

    it "instantiates model without components" do
      ar = ar_class.new(any_id)
      ar.components = [any_object]

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
      model.components.must_equal nil
    end

    it "persists new model without components" do
      model = model_class.new
      model.components = [any_object]

      id = any_id
      ar = ar_class.new(id)
      ar_class.expects(:create!).with({}).returns(ar)

      mapper.create!(model)

      model.id.must_equal id
    end
  end

  describe "attribute in AR only" do
    let(:ar_class) { ar_class_with_attributes([:id, :attribute]) }
    let(:model_class) { class_with_attributes([:id]) }
    let(:mapper) do
      mapper_class(
        'AttributeMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
      )
    end
    
    it "instantiates model" do
      ar = ar_class.new(any_id)
      ar.attribute = 'any string'

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
    end

    it "creates model" do
      model = model_class.new

      id = any_id
      ar = ar_class.new(id)
      ar_class.expects(:create!).with({}).returns(ar)

      mapper.create!(model)

      model.id.must_equal id
    end
  end

  describe "attribute in model only" do
    let(:ar_class) { ar_class_with_attributes([:id]) }
    let(:model_class) { class_with_attributes([:id, :attribute]) }
    let(:mapper) do
      mapper_class(
        'AttributeMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
      )
    end
    
    it "instantiates model" do
      ar = ar_class.new(any_id)

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
      model.attribute.must_equal nil
    end

    it "creates model" do
      model = model_class.new
      model.attribute = 'any string'

      id = any_id
      ar = ar_class.new(id)
      ar_class.expects(:create!).with({}).returns(ar)

      mapper.create!(model)

      model.id.must_equal id
    end
  end

  describe "semantic keys" do
    let(:ar_class)    { ar_class_with_attributes([:id, :key1, :key2, :field]) }
    let(:model_class) { class_with_attributes([:id, :key1, :key2, :field]) }
    let(:mapper) do
      mapper_class(
        'SemanticMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |ar| model_class.new },
        simple_attr: [:key1, :key2, :field],
        semantic_key: [:key1, :key2]
      )
    end
    
    it "saves new object" do
      model = model_class.new
      model.key1 = 10
      model.key2 = 20
      model.field = 'any string'

      ar_class.stubs(:find_by)

      id = any_id
      ar = ar_class.new(id)
      ar_class.expects(:create!).with(key1: model.key1, key2: model.key2, field: model.field).returns(ar)

      mapper.save!(model)

      model.id.must_equal id
    end

    it "saves existing object" do
      model = model_class.new
      model.key1 = 10
      model.key2 = 20
      model.field = 'any string'

      id = any_id
      ar = ar_class.new(id)

      ar_class.stubs(:find_by).with(key1: model.key1, key2: model.key2).returns(ar)
      ar_class.expects(:update).with(id, key1: model.key1, key2: model.key2, field: model.field)

      mapper.save!(model)

      model.id.must_equal id
    end

    it "checks existence with technical key" do
      model = model_class.new
      model.id = 1

      ar_class.stubs(:exists?).with(model.id).returns(true)

      mapper.exists?(model).must_equal true
    end

    it "checks existence with semantic key" do
      model = model_class.new
      model.key1 = 10
      model.key2 = 20

      tech_key = 100

      ar_class.stubs(:find_by).with(key1: 10, key2: 20).returns(ar_class.new(tech_key))

      mapper.exists?(model).must_equal true
      model.id.must_equal tech_key
    end
  end

  describe "composition" do
    let(:parts_ar_class)    { ar_class_with_attributes([:id, :simple]) }
    let(:parts_model_class) { ar_class_with_attributes([:id, :simple]) }
    let(:parts_mapper) do
      mapper_class(
        'PartsMapper',
        active_record_class: parts_ar_class,
        simple_attr: [:simple],
        composes: 'composite'
      )
    end

    let(:ar_class)    { ar_class_with_attributes([:id, :parts]) }
    let(:model_class) { class_with_attributes([:id, :parts]) }
    let(:mapper) do
      mapper_class(
        'CompositeMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |ar| model_class.new },
        composed_of: { parts: parts_mapper }
      )
    end
    
    it "instantiates model with parts" do
      id = any_id
      part = any_object

      ar = ar_class.new(id)

      parts_mapper.stubs(:where).with(composite_id: id).returns([part])

      model = mapper.model_for(ar)

      model.id.must_equal id
      model.parts.must_equal [part]
    end

    it "creates parts when creating object" do
      part = parts_ar_class.new
      part.simple = 'any string'

      model = model_class.new
      model.parts = [part]

      id = any_id
      ar = ar_class.new(id)
      ar_class.stubs(:create!).returns(ar)

      parts_ar = parts_ar_class.new(any_id)
      parts_ar_class.expects(:create!).with(simple: part.simple, composite_id: id, index: 0).returns(parts_ar)

      mapper.create!(model)
    end

    it "updates parts when updating object" do
      part1 = parts_model_class.new(10)
      part1.simple = 'existing part'

      part2 = parts_model_class.new
      part2.simple = 'new part'

      id = any_id
      model = model_class.new(id)
      model.parts = [part1, part2]

      parts_ar_class.expects(:where).with(composite_id: id).returns(parts_ar_class)
      parts_ar_class.expects(:where).with().returns(parts_ar_class)
      parts_ar_class.expects(:not).with(id: [part1.id]).returns(parts_ar_class)
      parts_ar_class.expects(:delete_all)

      parts_ar_class.expects(:update).with(part1.id, simple: part1.simple, composite_id: id, index: 0)

      ar = parts_ar_class.new(id)
      parts_ar_class.expects(:create!).with(simple: part2.simple, composite_id: id, index: 1).returns(ar)

      mapper.update(model)
    end
  end
end
