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

      def save!
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
      collection_attr attributes[:collection_attr] if attributes[:collection_attr]
      semantic_key attributes[:semantic_key] if attributes[:semantic_key]
      composed_of attributes[:composed_of] if attributes[:composed_of]
      composes attributes[:composes] if attributes[:composes]

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

    it "maps when finding" do
      id = any_id
      result_ar = ar_class.new(id)
      result_ar.attribute = 'any string'

      ar_class.stubs(:find).with(id).returns(result_ar)

      model = mapper.find!(id)

      model.id.must_equal result_ar.id
      model.attribute.must_equal result_ar.attribute
    end

    it "maps when saving existing object" do
      model = model_class.new(any_id)
      model.attribute = 'any string'
      ar = ar_class.new
      ar.expects(:save!)

      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
      ar.attribute.must_equal model.attribute
    end

    it "maps when saving new object" do
      model = model_class.new
      model.attribute = 'any string'

      id = any_id
      ar = ar_class.new(id)
      ar.expects(:save!)
      ar_class.stubs(:new).returns(ar)

      mapper.save!(model)

      ar.attribute.must_equal model.attribute
      model.id.must_equal id
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
    
    it "maps ar to model" do
      object = any_object
      ref_mapper.stubs(:find!).returns(object)

      ar = ar_class.new(any_id)

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
      model.object.must_equal object
    end

    it "maps when saving existing object" do
      model = model_class.new(any_id)
      model.object = stub(id: 10)

      ar = ar_class.new
      ar.expects(:save!)

      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
      ar.object_id.must_equal model.object.id
    end
  end

  describe "collection attribute" do
    let(:ar_class) { ar_class_with_attributes([:id, :collection]) }
    let(:model_class) { class_with_attributes([:id, :collection]) }
    let(:mapper) do
      mapper_class(
        'CollectionMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        collection_attr: { collection: MapperStub }
      )
    end 

    it "does not map collection to model" do
      ar = ar_class.new(any_id)
      ar.collection = [any_object]

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
      model.collection.must_equal nil
    end

    #it "converts to AR with option" do
    #  model = stub(id: nil, attribute: [Object.new, Object.new])

    #  ar = mapper.to_ar(model, include: [:attribute])

    #  ar.id.must_equal model.id
    #  ar.attribute[0].must_equal attribute
    #  ar.attribute[1].must_equal attribute
    #end

    it "does not save colleciton" do
      model = model_class.new(any_id)
      model.collection = [any_object]

      ar = ar_class.new
      ar.expects(:save!)
      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
      ar.collection.must_equal nil
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
    
    it "maps ar to model" do
      ar = ar_class.new(any_id)
      ar.attribute = 'any string'

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
    end

    it "maps when saving existing object" do
      model = model_class.new(any_id)

      ar = ar_class.new
      ar.expects(:save!)
      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
      ar.attribute.must_equal nil
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
    
    it "maps ar to model" do
      ar = ar_class.new(any_id)

      model = mapper.model_for(ar)

      model.id.must_equal ar.id
      model.attribute.must_equal nil
    end

    it "maps when saving existing object" do
      model = model_class.new(any_id)
      model.attribute = 'any string'

      ar = ar_class.new
      ar.expects(:save!)
      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
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
    
    it "maps when saving existing object" do
      id = any_id
      model = model_class.new
      model.key1 = 10
      model.key2 = 20
      model.field = 'any string'

      ar = ar_class.new(id)
      ar.expects(:save!)

      ar_class.stubs(:find).with(key1: 10, key2: 20).returns(ar)

      mapper.save!(model)

      ar.id.must_equal id
      ar.key1.must_equal model.key1
      ar.key2.must_equal model.key2
      ar.field.must_equal model.field
    end
  end

  describe "composition" do
    let(:parts_ar_class) { ar_class_with_attributes([:id]) }
    let(:parts_mapper) do
      mapper_class(
        'PartsMapper',
        active_record_class: parts_ar_class,
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
    
    it "maps when creating model for record" do
      id = any_id
      part = any_object

      ar = ar_class.new(id)

      parts_mapper.stubs(:where).with(composite_id: id).returns([part])

      model = mapper.model_for(ar)

      model.id.must_equal id
      model.parts.must_equal [part]
    end

    it "saves part" do
      part = any_object

      model = model_class.new
      model.parts = [part]

      id = any_id
      ar = ar_class.new(id)
      ar_class.stubs(:new).returns(ar)

      parts_mapper.expects(:save!).with(part, composite_id: id, index: 0)

      mapper.save!(model)
    end
  end
end
