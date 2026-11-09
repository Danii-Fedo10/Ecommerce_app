import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models.dart';
import '../state/app_state.dart';
import 'product_screen.dart';

class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p.id))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Container(
                width: double.infinity,
                color: kGreen.withValues(alpha: 0.08),
                alignment: Alignment.center,
                // Replace with CachedNetworkImage(p.imageUrl) once the backend serves photos.
                child: Text(p.emoji, style: const TextStyle(fontSize: 54)),
              ),
              Positioned(
                right: 2, top: 2,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(s.wishlist.contains(p.id) ? Icons.favorite : Icons.favorite_border, color: kRed),
                  onPressed: () => s.toggleWish(p.id),
                ),
              ),
              if (p.wholesale)
                Positioned(left: 8, top: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kYellow, borderRadius: BorderRadius.circular(6)),
                  child: Text('MOQ ${p.moq}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.pname(p), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Text(etb(p.price), style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                if (p.oldPrice != null) ...[
                  const SizedBox(width: 6),
                  Text(etb(p.oldPrice!), style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                if (p.reviews > 0) const Icon(Icons.star, size: 14, color: Colors.amber),
                Text(p.reviews > 0 ? ' ${p.rating} · ${p.sold} ${s.t('sold')}' : 'New', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
              Row(children: [
                const Icon(Icons.place_outlined, size: 13, color: Colors.black45),
                Expanded(child: Text(p.tera, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54))),
                if (p.verified) const Icon(Icons.verified, size: 14, color: kGreen),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
