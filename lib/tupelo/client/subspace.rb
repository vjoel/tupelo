class Tupelo::Client
  module Api
    TUPELO_SUBSPACE_TAG = "tupelo subspace".freeze
    TUPELO_META_KEY = "__tupelo__".freeze

    def define_subspace tag, template, addr: nil
      metatuple = {
        TUPELO_META_KEY => "subspace",
        tag:        tag,
        template:   PortableObjectTemplate.spec_from(template),
        addr:       addr
      }
      write_wait metatuple
    end

    # call this just once at start of first client (it's optional to
    # preserve behavior of non-subspace-aware code); this is done automatically
    # in the app framework
    def use_subspaces!
      return if find_subspace_by_tag(TUPELO_SUBSPACE_TAG)
      define_subspace(TUPELO_SUBSPACE_TAG, {
        TUPELO_META_KEY => "subspace",
        tag:        nil,
        template:   nil,
        addr:       nil
      })
    end

    def subspace tag
      tag = tag.to_s
      find_subspace_by_tag(tag) or begin
        if subscribed_tags.include? tag
          read TUPELO_META_KEY => "subspace",
            tag:      tag,
            template: nil,
            addr:     nil
          find_subspace_by_tag tag
        end
      end
      ## this impl will not be safe with dynamic subspaces
    end

    def find_subspace_by_tag tag
      worker.find_subspace_by_tag tag
    end
  end
end
