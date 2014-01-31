class Tupelo::Client
  module Api
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
    # preserve behavior of non-subspace-aware code)
    def use_subspaces!
      return if subspace(TUPELO_SUBSPACE_TAG)
      define_subspace(TUPELO_SUBSPACE_TAG, {
        TUPELO_META_KEY => "subspace",
        tag:        nil,
        template:   nil,
        addr:       nil
      })
    end

    def subspace tag
      tag = tag.to_s
      worker.subspaces.find {|sp| sp.tag == tag} or begin
        if subscribed_tags.include? tag
          read TUPELO_META_KEY => "subspace",
            tag:      tag,
            template: nil,
            addr:     nil
          worker.subspaces.find {|sp| sp.tag == tag}
        end
      end
      ## this impl will not be safe with dynamic subspaces
    end
  end
end
