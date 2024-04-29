import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class BadgeGrouping extends RestModel {
  @discourseComputed("name")
  i18nNameKey() {
    return this.name.toLowerCase().replace(/\s/g, "_");
  }

  @discourseComputed("name")
  displayName() {
    const i18nKey = `badges.badge_grouping.${this.i18nNameKey}.name`;
    return I18n.t(i18nKey, { defaultValue: this.name });
  }
}
