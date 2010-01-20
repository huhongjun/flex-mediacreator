package org.asblog.core 
{
	import org.asblog.contextmenu.ContextMenuLabels;
	import org.asblog.contextmenu.ContextMenuPlus;
	import org.asblog.event.MediaContainerEvent;
	import org.asblog.event.MediaItemEvent;
	import org.asblog.mediaItem.MediaImage;
	import org.asblog.mediaItem.MediaShape;
	import org.asblog.mxml.IMXML;
	import org.asblog.transform.TransformTool;
	import org.asblog.transform.TransformToolControl;
	import org.asblog.transform.TransformToolEvent;
	
	import flash.display.DisplayObject;
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.ui.Keyboard;
	
	import mx.collections.ArrayCollection;
	import mx.containers.Canvas;
	import mx.core.UIComponent;
	import mx.events.DragEvent;
	import mx.events.FlexEvent;
	import mx.managers.DragManager;
	
	import ui.Snapshot;

	/**
	 * 当有东西被拖近来时触发
	 */	
	[Event(name="onAddChild", type="org.asblog.event.MediaContainerEvent")]

	/**
	 * 当拖近来的东西被选中时触发
	 */	
	[Event(name="onSelect", type="org.asblog.event.MediaItemEvent")]

	/**
	 * 对某一对象进行转换时触发(比如大小，位置之类的改变)
	 */	
	[Event(name="transformTarget", type="flash.events.Event")]
	/**
	 * 索引改变
	 */
	[Event(name="indexChange", type="flash.events.Event")]
	/**
	 * 画布 
	 * @author Halley
	 */	
	public class DesignCanvas extends Canvas implements IMXML
	{
		private var _bgPolicy : String = "lashen";
		private var _transformTool : TransformTool;
		private var _selectedItem : IMediaObject;
		private var _selectedItems : Vector.<IMediaObject> = new Vector.<IMediaObject>( );
		private var _selectedIndices : Array = [];
		private var _selectedArea : IMediaObjectContainer;
		private var _itemList : ArrayCollection;
		/**
		 * 背景容器
		 */
		private var _background : IMediaObject;
		/**
		 * 画布容器（只存放可选中的东西,不包括转换工具，背景）
		 */
		private var _canvasContent : UIComponent;
		private var _canvasRBG : uint;
		//private var _selectionCanvas : Canvas;
		//private var _selecting : Boolean = false;
		
		/**
		 * 右键菜单
		 */		
		private var _cm : ContextMenuPlus;
		/**
		 * 背景 
		 * @return  IMediaObject
		 */		
		public function get background():IMediaObject
		{
			return _background;
		}
		
		/**
		 * 设置背景是平铺还是拉伸
		 */		
		[Bindable]

		public function get bgPolicy() : String 
		{
			return _bgPolicy;
		}

		public function set bgPolicy(v : String) : void 
		{
			_bgPolicy = v;
			if(v == "tile")
			{
			
			}
			else 
			{
				background.relatedObject.width = background.width = 1024;
				background.relatedObject.height = background.height = 768;
			}
		}

		/**
		 * 画布背景色
		 * @return 
		 * 
		 */		
		[Bindable]

		public function get canvasRBG() : uint 
		{
			return _canvasRBG;
		}

		public function set canvasRBG(v : uint) : void 
		{
			/*
			_canvasRBG = v;
			if(_background is MediaShape) 
			{
				MediaShape( _background ).doDrawRect( width, height, v );
			}
			else 
			{
				removeChild( DisplayObject(_background) );
				_background = new MediaShape( );
				_background.isBackground = true;
				MediaShape( background ).doDrawRect( width, height, v );
				addChild( DisplayObject(background) );
				setChildIndex( DisplayObject(background), 0 );
			}*/
		}
		override public function set width(value : Number) : void
		{
			super.width = value;
			background.relatedObject.width = width;
		}
		
		override public function set height(value : Number) : void
		{
			super.height = value;
			background.relatedObject.height = height;
		}
		/**
		 * 返回对主容器的引用
		 */
		public function get canvasContent() : UIComponent
		{
			return _canvasContent;
		}

		/**
		 * 是否选中的是画布
		 */		
		[Bindable]
		public var isCanvasSelected : Boolean = true;
		public function DesignCanvas() 
		{
			super( );
			chageBackground();
			initItemList( );
			initContent( );
			initTransformTool( );
			initMultiSelection( );
			initContextMenu( );			this.addEventListener( MouseEvent.MOUSE_DOWN, onMouseDown );
			this.addEventListener( MouseEvent.MOUSE_UP, mouseUp );
			this.addEventListener( DragEvent.DRAG_ENTER, onDragEnter );
			this.addEventListener( Event.ADDED_TO_STAGE, onAddToStage );
		}

		private function onAddToStage(event : Event) : void
		{
			stage.addEventListener( KeyboardEvent.KEY_DOWN, onKeyboardEvent );
		}

		//------------------公有方法-------------------
		/**
		 * 通过UID找到IMediaObject 
		 * @param uid 目标元件的UID
		 * @return 目标元件
		 */		
		public function getItemByUid(uid : String) : IMediaObject
		{
			var item:IMediaObject;
			for( var i:int = 0;i < itemList.length;i++ )
			{
				item = IMediaObject(itemList.getItemAt(i));
				if(item.uid == uid)	   return item;
			}
			return null;
		}

		/**
		 * 把工具移动到最上方 
		 * @param target
		 */		
		public function setToTop(target : DisplayObject) : void 
		{
			setChildIndex( target, numChildren - 1 );
		}

		/**
		 * 里面会调用seekIMediaObject查找IMediaObject类型的元件
		 * @param v 目标元件，可以是对象内部的可视元素或者元件的uid
		 * @param canMove 是不是拖拽进来的(选择后是否可立刻移动)
		 */		
		public function setSelection(v : *,canMove : Boolean = true,triggerEvent : Boolean = true) : void 
		{
			//trace( "setSelection" );
			if(v != null)
			{
				var target : IMediaObject;
				if(v is String)	
				{
					target = getItemByUid( String( v ) );
				}
				else
				{
					//得到目标对象	为IMediaObject。否则返回空
					target = seekIMediaObject( v ) as IMediaObject;
				}
				//目标不为空
				if(target != null && target.selectEnabled) 
				{
					/*
					//触发这个事件有利与外界改变被选对象
					var eve : MediaItemEvent = new MediaItemEvent( MediaItemEvent.BEFORE_SELECT );
					v.dispatchEvent( eve );*/

					if(canMove)
					{
						//trace( "可以立即移动" );
						_transformTool.moveNewTargets = true;
						_transformTool.moveEnabled = true;
					}
					else
					{
						//trace( "不可立即移动" );
						_transformTool.moveNewTargets = false;
					}
					_transformTool.target = target;
					isCanvasSelected = false;
					if(target is IMediaObjectContainer) 
					{
						_transformTool.registration = _transformTool.boundsTopLeft;
					}
					else
					{
						_transformTool.registration = _transformTool.boundsCenter;
					}
					//v.selected = true
					setToTop( _transformTool );
					if(triggerEvent)	
					{
						target.dispatchEvent( new MediaItemEvent( MediaItemEvent.SELECTED, target.mediaLink ) );
					}
					selectedItem = target;
					//如果targetObject被改变，将会选择更改后的对象
					setContextMenu( );
					dispatchEvent( new MediaItemEvent( MediaItemEvent.CHANGE, target.mediaLink ) );
				}
			}
			else
			{
				isCanvasSelected = true;
				_transformTool.target = null;
				selectedItem = null;
				if(triggerEvent)	dispatchEvent( new TransformToolEvent( TransformToolEvent.SETSELECTION ) );
			}
		}

		/**
		 * 如果有东西被拖近来就触发MediaContainerEvent的ADD_CHILD事件
		 * @param child
		 * @return 
		 */		
		public function addMediaItem(child : IMediaObject) : IMediaObject 
		{			
			var c : UIComponent = UIComponent( child );
			_canvasContent.addChild( c );
			
			_itemList.addItemAt( child, 0 );
			if(child.isComplete)
			{
				childAdded( child );
			}
			else
			{
				if(child is MediaImage) 
				{
					child.addEventListener( Event.COMPLETE, childAdded );
				}
				else
				{
				
					child.addEventListener( FlexEvent.CREATION_COMPLETE, childAdded );
				}
			}
			return child;
		}
		public function chageBackground(child:IMediaObject = null):void
		{
			var bg:DisplayObject;
			if(_background)	
			{
				_background.dispose();
				_background = null;
			}
			if( child )
			{
				bg = DisplayObject( child );
				if( child.mediaLink.isBackground ) 
				{
					_background = child;
					child.addEventListener( Event.COMPLETE, backgroundLoaded );
				}
			}
			else
			{
				_background = new MediaShape( );
				var link:ShapeLink = new ShapeLink( MediaShape.Rect );
				link.classRef = MediaShape;
				link.isBackground = true;
				link.width  = width;
				link.height = height;
				link.color = 0xFFFFFF;
				_background.mediaLink = link;
				_background.cacheAsBitmap = true;
				_background.percentHeight = 100;
				_background.percentWidth = 100;
				//_background.verticalScrollPolicy = ScrollPolicy.OFF;
				//_background.horizontalScrollPolicy = ScrollPolicy.OFF;
				MediaShape( _background ).draw();
				bg = DisplayObject(_background);
			}
			addChild( bg );
			setChildIndex( bg, 0 );
			//trace("_background:"+_background);
		}
		/**
		 * 添加一组元素 
		 * @param array
		 */		
		public function addMediaItems(array : Vector.<IMediaObject>) : void
		{
			for each(var child:IMediaObject in array)
			{
				addMediaItem(child);
			}
		}
		/**
		 * 删除指定的元素，并把转换工具置空
		 * @param child
		 * @return 
		 */		
		private function removeMediaItem(child : IMediaObject,cleanRef:Boolean = true) : void 
		{
			if(!child)
			{
				trace("要删除的元素为空");
				return;
			}
			itemList.removeItemAt( itemList.getItemIndex( child ) );
			child.dispose();
			if(cleanRef)	cleanReference();
		}
		/**
		 * 通过UID删除元素 
		 * @param uid UID的字符串
		 * @return 被删除的元素		 
		 */		
		public function removeMediaItemByUID(uid : String) : void 
		{
			removeMediaItem( getItemByUid( uid ) );
		}
		/**
		 * 删除选中的元素
		 */	
		public function removeSelectedMediaItems() : void 
		{
			removeMediaItem( _selectedItem );
			for each(var obj:IMediaObject in _selectedItems)
			{
				removeMediaItem( obj );
			}
		}

		/**
		 * 删除所有元素，不包括背景和转换工具，只是被拖进来的东西
		 */		
		public function removeAllMediaItem() : Vector.<MediaLink> 
		{
			var removedLinks:Vector.<MediaLink>;
			var removedItem:*;
			while(_canvasContent.numChildren)	
			{
				removedItem = _canvasContent.removeChildAt( 0 );
				if( removedItem is IMediaObject )
				{
					if(!removedLinks)	removedLinks = new Vector.<MediaLink>();
					removedLinks.push( IMediaObject( removedItem ).mediaLink );
				}
			}
			itemList = null;
			initItemList( );
			cleanReference( );
			return removedLinks;
		}

		public function parseMXML(mxml : MXML) : void 
		{
		}

		public function createMXML(container : IMediaObjectContainer = null) : MXML 
		{
			return null;
		}

		/**
		 * 弹出MXML的窗口
		 * 
		 */		
		public function showCodeWindow() : void 
		{
			/*
			var codeWin:PopUpTextWindow = PopUpManager.createPopUp( this, PopUpTextWindow, false ) as PopUpTextWindow;
			PopUpManager.centerPopUp( PopUpTextWindow as IFlexDisplayObject );
			codeWin.text = createMXML( ).toMXMLString( );*/
		}	

		//--------------私有方法-----------------
		/*
		private function onMove(eve : MouseEvent) : void {
		}*/
		private function initContent() : void
		{
			_canvasContent = new UIComponent( );
			_canvasContent.percentWidth = 100;
			_canvasContent.percentHeight = 100;
			addChild( _canvasContent );
		}

		private function initContextMenu() : void 
		{
			_cm = new ContextMenuPlus( );	
			this.contextMenu = _cm.contextMenu;
		}

		/**
		 *转变工具初始化 
		 * 
		 */		
		private function initTransformTool() : void 
		{
			_transformTool = new TransformTool( );
			//_transformTool.addControl(new CustomRotationControl())
			//不进行层级控制(就选择的东西原来什么级别就是什么级别)，如果是true点到的东西将被置顶
			_transformTool.raiseNewTargets = false;
			//_transformTool.livePreview = false;
			_transformTool.moveUnderObjects = false;			
			//_transformTool.constrainRotation = true;
			//_transformTool.constrainRotationAngle = 90 / 4;

			_transformTool.constrainScale = true;
			_transformTool.maxScaleX = 5;
			_transformTool.maxScaleY = 5;
			_transformTool.skewEnabled = true;
			//如果用了工具，此事件会一直发出
			_transformTool.addEventListener( TransformTool.TRANSFORM_TARGET, transformTarget );			_transformTool.addEventListener( TransformToolEvent.TARGET_MATRIX_CHANGE, targetMatrixChange );
			addChild( _transformTool );
		}

		
		/**
		 * 初始化元素集合
		 */		
		private function initItemList() : void 
		{
			itemList = new ArrayCollection( );

			//让深度高的排在前面
			/*
			var s : Sort = new Sort( );
			s.fields = [ new SortField( "depthAtParent", true, true ) ];
			itemList.sort = s;
			itemList.refresh( );*/
		}
		
		private function initMultiSelection() : void 
		{
			/*
			_selectionCanvas = new Canvas( );
			_selectionCanvas.setStyle( "backgroundAlpha", 0.3 );
			_selectionCanvas.setStyle( "backgroundColor", 0x316AC5 );
			addChild( _selectionCanvas );*/
		}

		/**
		 * 利用此事件实时更新被选元素的X，Y等属性
		 * @param eve
		 */		
		private function transformTarget(event : Event) : void 
		{
			dispatchEvent( event.clone( ) );
		}

		/**
		 * 目标的矩阵模型变更了
		 */
		private function targetMatrixChange(event : TransformToolEvent) : void
		{
			dispatchEvent( new TransformToolEvent( TransformToolEvent.TARGET_MATRIX_CHANGE, event.uid, event.oldMatrix, event.newMatrix ) );
		}

		/**
		 * 设置转变工具
		 * @param _transformTool 
		 */		
		public function set transformTool(t : TransformTool) : void 
		{
			_transformTool.removeEventListener( TransformTool.TRANSFORM_TARGET, transformTarget );
			_transformTool = t;
			_transformTool.addEventListener( TransformTool.TRANSFORM_TARGET, transformTarget );
		}

		/**
		 * @return 得到关联的转变工具
		 */		
		[Bindable]

		public function get transformTool() : TransformTool 
		{
			return _transformTool;
		}

		/**
		 * 此属性多用与绑定
		 * @return 当前选中的元素
		 */		
		[Bindable]
		public function get selectedItem() : IMediaObject 
		{
			return _selectedItem;
		}

		public function set selectedItem(v : IMediaObject) : void 
		{
			_selectedItem = v;
		}
		[Bindable]
		public function get selectedArea() : IMediaObjectContainer 
		{
			return _selectedArea;
		}

		public function set selectedArea(v : IMediaObjectContainer) : void 
		{			
			if(v == null) 
			{
				for each(var obj:IMediaObject in selectedItems) 
				{
					//DisplayObject(obj).transform.matrix = _selectedArea.transform.matrix;
					v.addChild( DisplayObject( obj ) );
				}
			}
			_selectedArea = v;
		}

		[Bindable]

		public function get selectedItems() : Vector.<IMediaObject>  
		{
			return _selectedItems;
		}

		public function set selectedItems(v : Vector.<IMediaObject> ) : void 
		{			
			_selectedItems = v;
		}

		[Bindable]

		public function get selectedIndices() : Array
		{
			return _selectedIndices;
		}

		public function set selectedIndices(v : Array ) : void 
		{			
			_selectedIndices = v;
		}

		/**
		 * 此属性多用与绑定,提供数据给图层管理
		 * @return 画布里有的所有显示元素的集合(不包括背景和TransformTool)
		 */		
		[Bindable]

		public function get itemList() : ArrayCollection 
		{
			return _itemList;
		}

		public function set itemList(v : ArrayCollection) : void 
		{
			_itemList = v;
		}

		private function onMouseDown(event : MouseEvent) : void 
		{
			var selectedObj : DisplayObject = DisplayObject( event.target );
			var toolEvent : TransformToolEvent;
			if(selectedObj is TransformToolControl)	return;			
			else if(_background.contains( selectedObj ) || selectedObj == this)
			{
				toolEvent = new TransformToolEvent( TransformToolEvent.SETSELECTION );
				toolEvent.selectedUid = null;				toolEvent.oldSelectedUid = _selectedItem != null ? _selectedItem.uid : null;
				dispatchEvent( toolEvent );
				//setSelection( null );
			}
			else
			{
				var target : IMediaObject;
				target = seekIMediaObject( selectedObj ) as IMediaObject;
				if(target != null && target != _selectedItem)
				{
					toolEvent = new TransformToolEvent( TransformToolEvent.SETSELECTION, target.uid );
					
					toolEvent.oldSelectedUid = _selectedItem != null ? _selectedItem.uid : null;
					toolEvent.selectedUid = target.uid;
					dispatchEvent( toolEvent );
				}
				//setToTop( _selectionCanvas );
				//_selecting = true;
				//setSelection( selectTarget );
				//onSelect( selectedObj );
			}			
			
			//初始化多选框
			/*
			_selectionCanvas.x = this.mouseX;
			_selectionCanvas.y = this.mouseY;
			_selectionCanvas.width = 1;
			_selectionCanvas.height = 1;
			 */
			//this.addEventListener( MouseEvent.MOUSE_MOVE, mouseMove );
		}

		private function mouseMove(event : MouseEvent) : void 
		{
			/*
			if(_selectedItem == null) 
			{
				var disX : Number = this.mouseX - _selectionCanvas.x;
				var disY : Number = this.mouseY - _selectionCanvas.y;
				_selectionCanvas.width = disX;
				_selectionCanvas.height = disY;
				event.updateAfterEvent( );
				checkHit( );
			}
			*/
		}

		/**
		 * 绑定选择区域，把里面的对象也绑定，并选择
		 * @param event
		 */		

		private function mouseUp(event : MouseEvent) : void 
		{
			//dispatchEvent( new MediaItemEvent( MediaItemEvent.BEFORE_ITEM_DOWN, _selectedItem.uid ) );			
			//如果有选择区域
			/*
			if(_selectionCanvas.width > 10 || _selectionCanvas.height > 10) 
			{
				
				var __selectedItems : Array = [];
				var __selectedIndices : Array = [];
				var container : IMediaObjectContainer;
				for each(var obj:IMediaObject in _itemList) 
				{
					if(obj.selected) 
					{
						if(!container)	container = new MediaObjectContainer( );
						__selectedIndices.push( itemList.getItemIndex( obj ) );
						__selectedItems.push( obj );
						if(obj.parent is IMediaObjectContainer) 
						{
							container = obj.parent as IMediaObjectContainer;
						}
						else 
						{
							container.addChild( DisplayObject( obj ) );
						}
					}
				}
				selectedItems = __selectedItems;
				selectedIndices = __selectedIndices;
				selectedArea = container;
				if(selectedItems != null)
				{					
					setSelection( DisplayObject( container ) );
					dispatchEvent( new MediaContainerEvent( MediaContainerEvent.MULYIP_SELECTION, container ) );
				}
				else
				{
					setSelection( null );
				}
			}
			with(_selectionCanvas) 
			{
				x = -1;
				y = -1;
				width = 0;
				height = 0;
			}
			this.removeEventListener( MouseEvent.MOUSE_MOVE, mouseMove );
			 * 
			 */
		}

		/**
		 * 碰撞检测
		 */		
		/*
		private function checkHit() : void 
		{
		for each(var obj:DisplayObject in _itemList) 
		{
		if(_selectionCanvas.hitTestObject( obj )) 
		{
		IMediaObject( obj ).selected = true;
		}
		else 
		{
		IMediaObject( obj ).selected = false;
		}
		}
		}*/

		/**
		 * 如果新添元件初始化完毕才触发MediaContainerEvent.ADD_CHILD事件
		 * @param eve
		 */		
		private function childAdded(eve : *,triggerEvent:Boolean = true) : void 
		{
			//trace( "childAdded" );
			var targetItem : IMediaObject;
			if(eve is Event)
			{
				targetItem = IMediaObject( eve.currentTarget );
				targetItem.isComplete = true;
				if(targetItem is MediaImage) 
				{
					targetItem.removeEventListener( Event.COMPLETE, childAdded );
				}
				else 
				{
					targetItem.removeEventListener( FlexEvent.CREATION_COMPLETE, childAdded );
				}
			}
			else
			{
				targetItem = eve;
			}
			setSelection( targetItem, false, false );
			if(triggerEvent)	dispatchEvent( new MediaContainerEvent( MediaContainerEvent.ADD_CHILD, targetItem.mediaLink ) );
		}
		private function backgroundLoaded(event:Event):void
		{
			var bg:MediaImage = MediaImage(event.currentTarget);
			bg.removeEventListener(Event.COMPLETE,backgroundLoaded);
			if(bg.mediaLink.isAdjuestImage)
			{
				width = bg.transform.pixelBounds.width;
				height = bg.transform.pixelBounds.height;
			}
			else
			{
				bg.width = width;
				bg.height = height;
			}
			
		}
		/**
		 * 清除相关引用，个选 
		 * 用在对象被删除，或者选中了画布，背景
		 */
		private function cleanReference() : void
		{
			setSelection( null, false, false );
		}

		/**
		 * 清除相关引用,多选
		 * 用在对象被删除，或者选中了画布，背景
		 */
		/*
		private function cleanMultiReference() : void {
		selectedArea = null;
		selectedItems = null;
		selectedIndices = null;
		}*/

		/**
		 * 检测是否超出指定范围
		 */		
		/*
		private function checkBorderline() : Boolean {
		var item : DisplayObject = DisplayObject(_selectedItem)
		var contentObj : DisplayObject = IRelatedObject(item).relatedObject;
		var r : Rectangle = item.getBounds(contentObj)

		var top : Number = 0;
		var left : Number = 0;
		var right : Number = contentObj.transform.pixelBounds.width; 
		var bottom : Number = contentObj.transform.pixelBounds.height;
		//trace(right,bottom)
		//trace(r.right,r.bottom)
		//trace(r.left,r.top)
		if(r.right > right || r.bottom > bottom || r.left < left || r.top < top) {
		trace("true");
		return true;
		}
		return false;
		}
		 */
		/**
		 * 递归寻找目标是否为IMediaObject如果不是找他的父级，次数小与500。
		 * @param target
		 * @return 
		 */		
		private function seekIMediaObject(target : DisplayObject) : DisplayObject 
		{
			var conut : int;
			conut++;
			if(target is IMediaObject)
				return target;
			else if(conut > 500)
				return null;
			else if(target.parent)
				return seekIMediaObject( target.parent );
			else
				return null;
		}

		/**
		 * 当有拖拽进入画布区域
		 * @param event
		 */		
		private function onDragEnter(event : DragEvent) : void 
		{
			if(event.dragInitiator is Snapshot) 
			{
				if(!Snapshot( event.dragInitiator ).mediaLink.isMask) 
				{
					DragManager.acceptDragDrop( this );
					DragManager.showFeedback( DragManager.COPY ); 
				}
			}
		}
		

		/**
		 * 监听键盘
		 * @param event
		 */		
		private function onKeyboardEvent(event : KeyboardEvent) : void 
		{
			switch (event.keyCode) 
			{
				case Keyboard.DELETE:
					if(_selectedItem != null) 
					{
						/*
						if(_selectedItem is IMediaObjectContainer) 
						{
						removeSelectedMediaItems( );
						}
						else if(_selectedItem.parent is MediaMask) 
						{
						removeChild( MediaMask( _selectedItem.parent ) );
						}
						else 
						{
						removeMediaItem( _selectedItem );
						}*/
						trace( "_selectedItem:", _selectedItem );
						dispatchEvent( new MediaContainerEvent( MediaContainerEvent.REMVOE_CHILD, _selectedItem.mediaLink ) );
					}
					break;
			}
		}

		/**
		 * 设置右键餐单
		 */		
		private function setContextMenu() : void 
		{
			_cm.addGroup( basicControl, true, ContextMenuLabels.BASIC_LABELS );
			_cm.addGroup( layerControl, true, ContextMenuLabels.LAYER_LABELS );
			_cm.addGroup( lockControl, true, ContextMenuLabels.LOCK_LABELS );
			_cm.addGroup( maskControl, true, ContextMenuLabels.MASK_LABELS );
			this.contextMenu = _cm.contextMenu;
		}

		
		
		private function basicControl(eve : ContextMenuEvent) : void 
		{
		}

		private function layerControl(eve : ContextMenuEvent) : void 
		{	
		}

		private function lockControl(eve : ContextMenuEvent) : void 
		{	
		}

		private function maskControl(eve : ContextMenuEvent) : void 
		{	
		}
	}
}