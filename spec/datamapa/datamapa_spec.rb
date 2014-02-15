require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
require 'mocha/setup'
require 'bourne'
require 'datamapa'

describe DataMapa do

  class Mapper
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

      # Provide name because this mapper class is anonymous
      define_singleton_method :name do
        class_name
      end
    end
  end

  let (:any_object) { Object.new }

  describe "simple attribute" do
    let(:ar_class) { class_with_attributes([:id, :attribute]) }
    let(:model_class) { class_with_attributes([:id, :attribute]) }
    let(:mapper) do
      mapper_class(
        'SimpleMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        simple_attr: [:id, :attribute]
      )
    end

    it "converts to model" do
      ar = stub(id: 1, attribute: 'any string')

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.attribute.must_equal ar.attribute
    end

    it "saves existing object" do
      model = model_class.new(1)
      model.attribute = 'any string'
      ar = ar_class.new
      ar.expects(:save!)

      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
      ar.attribute.must_equal model.attribute
    end
  end

  describe "ref attribute" do
    let(:model_class) { class_with_attributes([:id, :object]) }
    let(:ar_class) { class_with_attributes([:id, :object_id]) }
    let(:mapper) do
      mapper_class(
        'RefMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        simple_attr: [:id],
        ref_attr: { object: Mapper }
      )
    end
    
    it "converts to model without option" do
      ar = stub(id: 1, object: nil)
      ref = any_object
      Mapper.stubs(to_model: ref)

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.object.must_equal ref
    end

    it "saves existing object" do
      model = model_class.new(1)
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
    let(:ar_class) { class_with_attributes([:id, :collection]) }
    let(:model_class) { class_with_attributes([:id, :collection]) }
    let(:mapper) do
      mapper_class(
        'CollectionMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        simple_attr: [:id],
        collection_attr: { collection: Mapper }
      )
    end 
    
    it "converts to model with option" do
      Mapper.stubs(where: [any_object, any_object])
      model_instance = any_object
      Mapper.stubs(to_model: model_instance)

      ar = stub(id: 1)

      model = mapper.to_model(ar, include: [:collection])

      model.id.must_equal ar.id
      model.collection[0].must_equal model_instance
      model.collection[1].must_equal model_instance
    end

    it "does not convert to model without option" do
      ar = stub(id: 1, collection: [any_object])

      model = mapper.to_model(ar)

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

    it "does not save without option" do
      model = model_class.new(1)
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
    let(:ar_class) { class_with_attributes([:id, :attribute]) }
    let(:model_class) { class_with_attributes([:id]) }
    let(:mapper) do
      mapper_class(
        'AttributeMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        simple_attr: [:id]
      )
    end
    
    it "converts to model" do
      ar = stub(id: 1, attribute: 'any string')

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
    end

    it "saves existing object" do
      model = model_class.new(1)

      ar = ar_class.new
      ar.expects(:save!)
      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
      ar.attribute.must_equal nil
    end
  end

  describe "attribute in model only" do
    let(:ar_class) { class_with_attributes([:id]) }
    let(:model_class) { class_with_attributes([:id, :attribute]) }
    let(:mapper) do
      mapper_class(
        'AttributeMapper',
        active_record_class: ar_class,
        creates_model_with: lambda { |rec| model_class.new },
        simple_attr: [:id]
      )
    end
    
    it "converts to model" do
      ar = stub(id: 1)

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.attribute.must_equal nil
    end

    it "saves existing object" do
      model = model_class.new(1)
      model.attribute = 'any string'

      ar = ar_class.new
      ar.expects(:save!)
      ar_class.stubs(:find).returns(ar)

      mapper.save!(model)

      ar.id.must_equal model.id
    end
  end
end
