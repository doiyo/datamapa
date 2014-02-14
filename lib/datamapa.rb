require "datamapa/version"

module DataMapa
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Declarative methods
    def active_record_class(klass)
      @ar_class = klass
    end

    def model_constructor(method)
      @model_constructor = method
    end

    def creates_model_with(&block)
      @create_model_proc = block
    end

    def simple_attr(attributes)
      @simple_attr = attributes
    end

    def ref_attr(attributes)
      @ref_attr = attributes
    end

    def collection_attr(attributes)
      @collection_attr = attributes
    end

    def composed_of(parts)
      @composed_of = parts
    end

    def composes(parent)
      @composes = parent
    end

    # Public methods
    def to_ar(model, options={})
      ar = model.id ? @ar_class.find(model.id) : @ar_class.new

      o2r_attr(model, ar)
      o2r_ref(model, ar)
      o2r_collection(model, ar, options[:include]) if options[:include]

      ar
    end

    def to_model(ar, options={})
      model = @create_model_proc.call(ar)

      r2o_simple(ar, model)
      r2o_ref(ar, model)
      r2o_collection(ar, model, options[:include]) if options[:include]

      model
    end

    def find!(id)
      begin
        relational = @ar_class.find(id)
        to_model(relational, include: [@composed_of.keys])
      rescue ActiveRecord::RecordNotFound
        raise DataMapa::RecordNotFoundError
      end
    end

    def where(clause)
      records = @ar_class.where(clause) 
      records.map { |ar| to_model(ar, include: [@composed_of.keys]) }
    end

    def save!(model, extras={})
      begin
        ar = to_ar(model)
        extras.each_pair { |key, value| ar.send("#{key}=", value) }
        ar.save!
        model.send(:id=, ar.id)

        @composed_of.each do |parts, mapper|
          mapper.save_parts!(model.send(parts))
        end
      rescue ActiveRecord::StatementInvalid => e
        raise DataMapa::PersistenceError, e.message
      end
    end

    def save_parts!(parts, parent_id)
      parts.each_with_index do |item, i|
        save!(item, "#{@composes}_id".to_sym => parent_id, :index => i)
      end
    end

    def delete!(id)
      @composed_of.each do |part, mapper|
        mapper.delete_children_of(id)
      end

      count = @ar_class.delete(id)
    end

    private

    def delete_children_of(id)
      @ar_class.delete_all(["#{@composes}_id = ?", id])
    end

    def r2o_simple(relational, object)
      @simple_attr.each do |attr|
        setter = "#{attr.to_s.chomp('?')}="
        object.send(setter, relational.send(attr))
      end if @simple_attr
    end

    def r2o_ref(relational, object)
      @ref_attr.each do |attr, mapper|
        setter = "#{attr}="
        object.send(setter, mapper.to_model(relational.send(attr)))
      end if @ref_attr
    end

    def r2o_collection(ar, model, attributes)
      attributes.each do |attr|
        ar_items = @collection_attr[attr].where("#{model_name}_id".to_sym => ar.id)
        model_items = ar_items.map {|i| @collection_attr[attr].to_model(i)}
        model.send("#{attr}=", model_items)
      end
    end

    def model_name
      name.chomp('Mapper').downcase
    end

    def o2r_attr(object, relational)
      @simple_attr.each do |attr|
        relational.send("#{attr.to_s.chomp('?')}=", object.send(attr))
      end if @simple_attr
    end

    def o2r_ref(object, relational)
      @ref_attr.each_key do |attr|
        ref = object.send(attr)
        relational.send("#{attr.to_s.chomp('?')}_id=", ref.id) unless ref.nil?
      end if @ref_attr
    end

    #def o2r_collection(object, relational, attributes)
    #  attributes.each do |attr|
    #    collection = object.send(attr).map do |item| 
    #      @collection_attr[attr].to_ar(item)
    #    end
    #    relational.send("#{attr}=", collection)
    #  end
    #end
  end

  class PersistenceError < StandardError
  end

  class RecordNotFoundError < PersistenceError
  end

  class DuplicateKeyError < PersistenceError
  end
end
