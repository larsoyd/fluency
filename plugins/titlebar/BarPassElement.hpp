#pragma once
#include <hyprland/src/render/pass/PassElement.hpp>
#include "compat.hpp"

class CHyprBar;

class CBarPassElement : public IPassElement {
  public:
    struct SBarData {
        CHyprBar*            deco = nullptr;
        float                a    = 1.F;
        compat::Presentation presentation;
    };

    CBarPassElement(const SBarData& data_);
    virtual ~CBarPassElement() = default;

#ifdef COMPAT_RENDER_CONTEXT
    virtual std::vector<UP<IPassElement>> draw(compat::RenderContext& ctx) override;
    virtual bool                          needsLiveBlur(compat::RenderContext& ctx) override;
    virtual bool                          needsPrecomputeBlur(compat::RenderContext& ctx) override;
    virtual std::optional<CBox>           boundingBox(compat::RenderContext& ctx) override;
#else
    // TODO: temporary compat maintained for a few months after release then removed
    std::vector<UP<IPassElement>> draw(compat::RenderContext& ctx);
    bool                          needsLiveBlur(compat::RenderContext& ctx);
    bool                          needsPrecomputeBlur(compat::RenderContext& ctx);
    std::optional<CBox>           boundingBox(compat::RenderContext& ctx);

    virtual std::vector<UP<IPassElement>> draw() override {
        compat::RenderContext ctx;
        return draw(ctx);
    }
    virtual bool needsLiveBlur() override {
        compat::RenderContext ctx;
        return needsLiveBlur(ctx);
    }
    virtual bool needsPrecomputeBlur() override {
        compat::RenderContext ctx;
        return needsPrecomputeBlur(ctx);
    }
    virtual std::optional<CBox> boundingBox() override {
        compat::RenderContext ctx;
        return boundingBox(ctx);
    }
#endif

    virtual const char*                   passName() override {
        return "CBarPassElement";
    }

    virtual ePassElementType type() override {
        return EK_CUSTOM;
    }

  private:
    SBarData data;
};