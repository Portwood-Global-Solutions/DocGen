import LightningDatatable from 'lightning/datatable';
import imageCell from './imageCell.html';

/**
 * lightning-datatable has no built-in 'image' column type — a column declared
 * with an unknown type silently renders its value as plain text (which is how
 * the Assets tab ended up showing raw /sfc/ URLs instead of thumbnails). This
 * subclass registers a real 'image' type backed by imageCell.html.
 *
 * Column usage:
 *   { type: 'image', fieldName: 'thumbnailUrl',
 *     typeAttributes: { alt: { fieldName: 'name' }, height: 48 } }
 */
export default class DocGenImageDatatable extends LightningDatatable {
    static customTypes = {
        image: {
            template: imageCell,
            standardCellLayout: true,
            typeAttributes: ['alt', 'height']
        }
    };
}
