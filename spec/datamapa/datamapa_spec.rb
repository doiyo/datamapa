require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
require 'mocha/setup'
require 'datamapa'

describe DataMapa do

  def class_with_attributes(attributes)
    Class.new do
      attributes.each do |attr|
        attr_accessor attr
      end
    end
  end

  def mapper_class(ar_class, model_class, attributes)
    Class.new do
      include DataMapa

      active_record_class ar_class
      model_constructor model_class.method(:new)
      simple_attr attributes[:simple] if attributes[:simple]
      ref_attr attributes[:ref] if attributes[:ref]
      collection_attr attributes[:collection] if attributes[:collection]
    end
  end

  let (:any_object) { Object.new }

  describe "simple attribute" do
    let(:ar_class) { class_with_attributes([:id, :a1]) }
    let(:model_class) { class_with_attributes([:id, :a1]) }
    let(:mapper) { mapper_class(
      ar_class, model_class,
      simple: [:id, :a1]
    ) }

    it "converts to model" do
      ar = stub(id: 1, a1: 'any string')

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.a1.must_equal ar.a1
    end

    it "converts to ar" do
      model = stub(id: nil, a1: 'any string')

      ar = mapper.to_ar(model)

      ar.id.must_equal model.id
      ar.a1.must_equal model.a1
    end
  end

  describe "ref attribute" do
    let(:ar_class) { class_with_attributes([:id, :a1_id]) }
    let(:model_class) { class_with_attributes([:id, :a1]) }
    let(:a1_model) { any_object }
    let(:mapper) { mapper_class(
      ar_class, model_class,
      simple: [:id],
      ref: { a1: stub(to_model: a1_model) }
    ) }
    
    it "converts to model without option" do
      ar = stub(id: 1, a1: nil)

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.a1.must_equal a1_model
    end

    it "converts to AR" do
      model = stub(id: nil, a1: stub(id: 10))

      ar = mapper.to_ar(model)

      ar.id.must_equal model.id
      ar.a1_id.must_equal model.a1.id
    end
  end

  describe "collection attribute" do
    let(:ar_class) { class_with_attributes([:id, :a1]) }
    let(:model_class) { class_with_attributes([:id, :a1]) }
    let(:a1_model) { any_object }
    let(:a1_ar) { any_object }
    let(:mapper) { mapper_class(
      ar_class, model_class, 
      simple: [:id],
      collection: {a1: stub(to_model: a1_model, to_ar: a1_ar)}
    ) }
    
    it "converts to model with option" do
      ar = stub(id: 1, a1: [Object.new, Object.new])

      model = mapper.to_model(ar, include: [:a1])

      model.id.must_equal ar.id
      model.a1[0].must_equal a1_model
      model.a1[1].must_equal a1_model
    end

    it "does not convert to model without option" do
      ar = stub(id: 1, a1: [Object.new, Object.new])

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.a1.must_equal nil
    end

    it "converts to AR with option" do
      model = stub(id: nil, a1: [Object.new, Object.new])

      ar = mapper.to_ar(model, include: [:a1])

      ar.id.must_equal model.id
      ar.a1[0].must_equal a1_ar
      ar.a1[1].must_equal a1_ar
    end

    it "does not convert to AR without option" do
      model = stub(id: nil, a1: [Object.new, Object.new])

      ar = mapper.to_ar(model)

      ar.id.must_equal model.id
      ar.a1.must_equal nil
    end
  end

  describe "attribute in AR only" do
    let(:ar_class) { class_with_attributes([:id, :a1]) }
    let(:model_class) { class_with_attributes([:id]) }
    let(:mapper) { mapper_class(ar_class, model_class, simple: [:id]) }
    
    it "converts to model" do
      ar = stub(id: 1, a1: 'any string')

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
    end

    it "converts to AR" do
      model = stub(id: nil)

      ar = mapper.to_ar(model)

      ar.id.must_equal model.id
      ar.a1.must_equal nil
    end
  end

  describe "attribute in model only" do
    let(:ar_class) { class_with_attributes([:id]) }
    let(:model_class) { class_with_attributes([:id, :a1]) }
    let(:mapper) { mapper_class(ar_class, model_class, simple: [:id]) }
    
    it "converts to model" do
      ar = stub(id: 1)

      model = mapper.to_model(ar)

      model.id.must_equal ar.id
      model.a1.must_equal nil
    end

    it "converts to AR" do
      model = stub(id: nil, a1: 'any string')

      ar = mapper.to_ar(model)

      ar.id.must_equal model.id
    end
  end
end
